# audit_handler.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'audit/audit_store'

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
      audit_store.clear_channel
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
    audit_store.cache_message(event.message) if audit_store.should_cache?
  end

  def on_message_delete(event)
    message_hash = audit_store.cached_message(event.id)
    found_user = find_user(message_hash['author'])
    user_text = found_user&.value&.mention || message_hash['author']

    post_audit_message('Message Delete',
                       channel: event.channel.mention,
                       author: user_text,
                       text: message_hash['text'])
  end

  def on_message_edit(event)
    message_hash = audit_store.cached_message(event.message.id)
    post_audit_message('Message Edit',
                       channel: event.channel.mention,
                       author: event.author.mention,
                       old_text: message_hash['text'],
                       new_text: event.content)

    on_message(event) # Update the cache
  end

  private

  def audit_store
    @audit_store ||= AuditStore.new(server_redis, config.message_cache_time)
  end

  def post_audit_message(event_type, **data)
    return unless audit_store.channel_set?

    message = "***#{event_type}***\n#{'-' * event_type.length}"

    message += data.map { |key, value| "\n**#{key.capitalize}**: #{value}" }.join

    audit_channel.send_message(message)
  end

  def audit_channel
    bot.channel(audit_store.channel, @server)
  end

  def update_audit_channel(channel)
    found_channel = find_channel(channel)

    return found_channel.error if found_channel.failure?

    audit_store.channel = found_channel.value.id

    "Audit channel has been set to #{found_channel.value.mention}"
  end

  def manage_audit_summary
    return 'Audit is disabled, set an Audit channel to enable' unless audit_store.channel_set?

    response = "Audit channel: #{audit_channel.mention}"

    if !audit_store.enabled?
      response += "\nMessage caching is disabled"
    elsif !audit_store.can_encrypt?
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
end
