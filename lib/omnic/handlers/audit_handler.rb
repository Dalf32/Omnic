# audit_handler.rb
#
# AUTHOR::  Kyle Mullins

class AuditHandler < CommandHandler
  command :auditchannel, :set_audit_channel, min_args: 1, max_args: 1,
      required_permissions: [:administrator], usage: 'auditchannel [channel_name]',
      description: 'Sets or clears the channel for audit messages.'

  event :member_join, :on_member_join

  event :member_leave, :on_member_leave

  event :message, :on_message

  event :message_delete, :on_message_delete

  event :message_edit, :on_message_edit

  def config_name
    :audit
  end

  def redis_name
    :audit
  end

  def set_audit_channel(event, *channel)
    if channel.empty?
      server_redis.del(:audit_channel)
      return 'Audit channel has been cleared.'
    end

    channels = bot.find_channel(channel.first, event.server.name, type: 0)

    return "#{channel} does not match any channels on this server" if channels.empty?
    return "#{channel} matches more than one channel on this server" if channels.count > 1

    server_redis.set(:audit_channel, channels.first.id)

    "Audit channel has been set to #{channels.first.name}"
  end

  def on_member_join(event)
    post_audit_message('Member Join', user: event.user)
  end

  def on_member_leave(event)
    post_audit_message('Member Leave', user: event.user)
  end

  def on_message(event)
    cache_message(event.message) if cache_enabled?
  end

  def on_message_delete(event)
    message_hash = get_cached_message(event.id)
    post_audit_message('Message Delete',
                       channel: "##{event.channel.name}",
                       author: message_hash['author'],
                       text: message_hash['text'])
  end

  def on_message_edit(event)
    message_hash = get_cached_message(event.message.id)
    post_audit_message('Message Edit',
                       channel: "##{event.channel.name}",
                       author: event.author.distinct,
                       old_text: message_hash['text'],
                       new_text: event.content)

    on_message(event) # Update the cache
  end

  private

  def cache_enabled?
    config.message_cache_time.positive?
  end

  def cache_message(message)
    cache_key = cache_key(message.id)
    server_redis.hmset(cache_key, :author, message.author.distinct,
                       :text, message.text)
    server_redis.expire(cache_key, config.message_cache_time * 60)
  end

  def get_cached_message(message_id)
    cache_key = cache_key(message_id)

    if server_redis.exists(cache_key)
      server_redis.hgetall(cache_key).to_h
    else
      default_text = '*[Message Unavailable]*'
      { 'text' => default_text, 'author' => default_text }
    end
  end

  def cache_key(message_id)
    "message_cache:#{message_id}"
  end

  def audits_enabled?
    server_redis.exists(:audit_channel)
  end

  def post_audit_message(event_type, **data)
    return unless audits_enabled?

    message = "***#{event_type}***\n#{'-' * event_type.length}"

    message += data.map { |key, value| "\n**#{key.capitalize}**: #{value}" }.join

    audit_channel.send_message(message)
  end

  def audit_channel
    channel_id = server_redis.get(:audit_channel)
    bot.channel(channel_id, @server)
  end
end
