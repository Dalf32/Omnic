# admin_functions_handler.rb
#
# Author::  Kyle Mullins

class AdminFunctionsHandler < CommandHandler
  command(:limitcmd, :limit_command)
    .min_args(3).permissions(:manage_server).pm_enabled(false)
    .usage('limitcmd <command> <allow/deny/whitelist/blacklist> <channel> [additional_channels...]')
    .description('If the second argument is allow/whitelist, limits the given command name so that it can only be used in the listed Channel(s) on this Server; '\
                   'if it is deny/blacklist, limits the given Command name so that it can not be used in the listed Channel(s) on this Server.')

  command(:limitclr, :clear_command_limits)
    .args_range(1, 1).permissions(:manage_server).pm_enabled(false)
    .usage('limitclr <command>')
    .description('Removes all channel limits for the given Command name on this Server.')

  command(:inviteurl, :invite_url)
    .permissions(:manage_server).max_args(0).usage('inviteurl')
    .description('Generates a URL which can be used to invite this bot to a server.')

  command(:features, :list_features)
    .permissions(:manage_server).max_args(0).usage('features')
    .description('Lists all the loaded Features and the Commands controlled by them.')

  command(:feature, :set_feature_on_off)
    .args_range(2, 2).permissions(:manage_server).pm_enabled(false)
    .usage('feature <feature> <on/off/enable/disable>')
    .description('Enables (on) or Disables (off) the named Feature.')

  command(:loglevels, :show_log_levels)
    .owner_only(true).max_args(0).usage('loglevels')
    .description('Lists all log appenders and their logging levels.')

  command(:setloglevel, :set_log_level)
    .args_range(2, 2).owner_only(true)
    .usage('setloglevel <log_name> <log_level>')
    .description('Sets the logging level for the named appender to the given level.')

  def redis_name
    :admin
  end

  def limit_command(event, command, allow_deny, *channel_list)
    error_message = nil
    error_message = 'Second parameter must be one of the following: allow, deny, whitelist, blacklist.' unless %w[allow deny whitelist blacklist].include?(allow_deny)
    error_message = "#{command} is not a recognized command." unless bot.commands.key?(command.to_sym)
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

    channel_ids = channel_list.map { |channel_name| bot.find_channel(channel_name, event.server.name, type: 0) }.flatten.map(&:id)

    if %w[allow whitelist].include?(allow_deny)
      whitelist_channels(command, channel_ids)
    else
      blacklist_channels(command, channel_ids)
    end
  end

  def clear_command_limits(_event, command)
    return "'#{command}' is not a recognized command." unless bot.commands.key?(command.to_sym)

    clear_lists(command)
    "All limits cleared for command '#{command}'"
  end

  def invite_url(_event)
    bot.invite_url
  end

  def list_features(_event)
    Omnic.features.values.map { |f| f.to_s(feature_redis) }.join("\n")
  end

  def set_feature_on_off(_event, feature, on_off)
    return 'Second parameter must be one of the following: enable, disable, on, off.' unless %w[enable disable on off].include?(on_off)
    return "'#{feature}' is not a recognized feature." unless Omnic.features.key?(feature.to_sym)

    is_enabled = %w[enable on].include?(on_off)
    Omnic.features[feature.to_sym].set_enabled(feature_redis, is_enabled)

    "Feature '#{feature}' has been #{is_enabled ? 'enabled' : 'disabled'} for this server."
  end

  def show_log_levels(_event)
    log.appenders.map { |appender| "#{appender.name}: #{Logging::LEVELS.invert[appender.level]}" }.join("\n")
  end

  def set_log_level(_event, log_name, log_level)
    appender = Logging::Appenders[log_name]
    level = Logging::LEVELS[log_level]

    return "There is no log appender with the name '#{log_name}'." if appender.nil?
    return "There is no log level with the name '#{log_level}'." if level.nil?

    appender.level = level

    "Log appender #{log_name} now has level #{log_level}."
  end

  private

  def feature_redis
    Redis::Namespace.new(get_server_namespace(@server), redis: Omnic.redis)
  end

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
