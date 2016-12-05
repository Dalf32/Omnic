# admin_functions_handler.rb
#
# Author::	Kyle Mullins

class AdminFunctionsHandler < CommandHandler
  command :limitcmd, :limit_command, min_args: 3, required_permissions: [:administrator],
      description: 'If the second argument is allow/whitelist, limits the given command name so that it can only be used in the listed Channel(s) on this Server; ' +
          'if it is deny/blacklist, limits the given Command name so that it can not be used in the listed Channel(s) on this Server.'
  command :limitclr, :clear_command_limits, min_args: 1, required_permissions: [:administrator],
      description: 'Removes all channel limits for the given Command name on this Server.'

  def redis_name
    :admin
  end

  def limit_command(event, command, allow_deny, *channel_list)
    error_message = nil
    error_message = 'This command cannot be used in a Private Message.' if is_pm?(event)
    error_message = 'Second parameter must be one of the following: allow, deny, whitelist, blacklist.' unless %w(allow deny whitelist blacklist).include?(allow_deny)
    error_message = "#{command} is not a recognized command." unless bot.commands.keys.include?(command.to_sym)
    error_message = 'You cannot limit that command' if command == 'limitcmd'

    all_channels_valid = true

    Array(channel_list).each do |channel|
      if bot.find_channel(channel, event.server.name, type: 0).empty?
        bot.send_temporary_message(event.channel.id, "#{channel} does not match any channels on this server", 10)
        all_channels_valid = false
      end
    end

    error_message = 'One or more listed channels were invalid.' unless all_channels_valid

    return error_message unless error_message.nil?

    channel_ids = channel_list.map{ |channel_name| bot.find_channel(channel_name, event.server.name, type: 0) }.flatten.map(&:id)

    if %w(allow whitelist).include?(allow_deny)
      whitelist_channels(command, channel_ids)
    else
      blacklist_channels(command, channel_ids)
    end
  end

  def clear_command_limits(_event, command)
    return "#{command} is not a recognized command." unless bot.commands.keys.include?(command.to_sym)

    clear_lists(command)
    "All limits cleared for command #{command}"
  end

  private

  def whitelist_channels(command, channel_ids)
    server_redis.sadd(whitelist_key(command), channel_ids)
    "#{channel_ids.count} channel#{channel_ids.count == 1 ? '' : 's'} added to whitelist for command #{command}"
  end

  def blacklist_channels(command, channel_ids)
    server_redis.sadd(blacklist_key(command), channel_ids)
    "#{channel_ids.count} channel#{channel_ids.count == 1 ? '' : 's'} added to blacklist for command #{command}"
  end

  def clear_lists(command)
    server_redis.del(whitelist_key(command))
    server_redis.del(blacklist_key(command))
  end

  def whitelist_key(command)
    "channel_whitelist:#{command}"
  end

  def blacklist_key(command)
    "channel_blacklist:#{command}"
  end
end
