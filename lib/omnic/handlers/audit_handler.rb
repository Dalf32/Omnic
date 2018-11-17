# audit_handler.rb
#
# AUTHOR::  Kyle Mullins

class AuditHandler < CommandHandler
  feature :audit, default_enabled: false

  command(:manageaudit, :manage_audit)
    .feature(:audit).args_range(0, 2).pm_enabled(false)
    .permissions(:manage_channels).usage('manageaudit [option] [argument]')
    .description('Used to manage audit options. Try the "help" option for more details.')

  event(:member_join, :on_member_join).feature(:audit).pm_enabled(false)

  event(:member_leave, :on_member_leave).feature(:audit).pm_enabled(false)

  event(:message, :on_message).feature(:audit).pm_enabled(false)

  event(:message_delete, :on_message_delete).feature(:audit).pm_enabled(false)

  event(:message_edit, :on_message_edit).feature(:audit).pm_enabled(false)

  def config_name
    :audit
  end

  def redis_name
    :audit
  end

  def manage_audit(_event, *args)
    return manage_audit_summary if args.empty?

    case args.first
    when 'help'
      manage_audit_help
    when 'channel'
      return 'Name of Channel is required' if args.size == 1

      update_audit_channel(args[1])
    when 'disable'
      server_redis.del(:audit_channel)
      'Audit has been disabled.'
    else
      'Invalid option.'
    end
  end

  def on_member_join(event)
    post_audit_message('Member Join', user: event.user.distinct)
  end

  def on_member_leave(event)
    post_audit_message('Member Leave', user: event.user.distinct)
  end

  def on_message(event)
    cache_message(event.message) if cache_enabled? && can_encrypt?
  end

  def on_message_delete(event)
    message_hash = get_cached_message(event.id)
    found_user = find_user(message_hash['author'])
    user_text = found_user&.value&.mention || message_hash['author']

    post_audit_message('Message Delete',
                       channel: event.channel.mention,
                       author: user_text,
                       text: message_hash['text'])
  end

  def on_message_edit(event)
    message_hash = get_cached_message(event.message.id)
    post_audit_message('Message Edit',
                       channel: event.channel.mention,
                       author: event.author.mention,
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
    text = Omnic.encryption.encrypt(message.text)
    server_redis.hmset(cache_key, :author, message.author.distinct, :text, text)
    server_redis.expire(cache_key, config.message_cache_time * 60)
  end

  def get_cached_message(message_id)
    cache_key = cache_key(message_id)

    if server_redis.exists(cache_key)
      server_redis.hgetall(cache_key).to_h.tap do |result|
        if can_encrypt?
          result['text'] = Omnic.encryption.decrypt(result['text'])
        end
      end
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

  def update_audit_channel(channel)
    found_channel = find_channel(channel)

    return found_channel.error if found_channel.failure?

    server_redis.set(:audit_channel, found_channel.value.id)

    "Audit channel has been set to #{found_channel.value.mention}"
  end

  def manage_audit_summary
    return 'Audit is disabled, set an Audit channel to enable' unless audits_enabled?

    response = "Audit channel: #{audit_channel.mention}"

    if !cache_enabled?
      response += "\nMessage caching is disabled"
    elsif !can_encrypt?
      response += "\nEncryption is not available, messages will not be cached."
    end

    response
  end

  def manage_audit_help
    <<~HELP
      help - Displays this help text
      channel <channel> - Sets the Channel Audit posts to
      disable - Disables Auditing
    HELP
  end

  def can_encrypt?
    !Omnic.encryption.nil?
  end
end
