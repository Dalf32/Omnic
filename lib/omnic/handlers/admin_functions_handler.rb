# admin_functions_handler.rb
#
# Author::  Kyle Mullins

require_relative 'admin/limits_store'

class AdminFunctionsHandler < CommandHandler
  command(:limitcmd, :limit_command)
    .min_args(3).permissions(:manage_server).pm_enabled(false)
    .usage('limitcmd <command> <allow|deny|whitelist|blacklist> <channel_name|"role"> [role_name|other_channels...]')
    .description('If the second argument is allow/whitelist, limits the given Command name so that it can *only* be used in the listed Channels or by someone with the Role on this Server; '\
                   'if it is deny/blacklist, limits the given Command name so that it *cannot* be used in the listed Channels or by someone with the Role on this Server; '\
                   'if the third argument is "role" then all subsequent text is considered as a Role name rather than Channel names.')

  command(:limitclr, :clear_command_limits)
    .args_range(1, 1).permissions(:manage_server).pm_enabled(false)
    .usage('limitclr <command>')
    .description('Removes all Channel and Role limits for the given Command name on this Server.')

  command(:cmdlimits, :show_command_limits)
    .args_range(0, 1).permissions(:manage_server).pm_enabled(false)
    .usage('cmdlimits [command]')
    .description('Displays the current limits applied to the given Command name on this Server or which Commands are limited.')

  command(:inviteurl, :invite_url).no_args.usage('inviteurl')
    .description('Generates a URL which can be used to invite this bot to a server.')

  command(:features, :list_features)
    .permissions(:manage_server).no_args.usage('features')
    .description('Lists all the loaded Features and the Commands controlled by them.')

  command(:feature, :set_feature_on_off)
    .args_range(2, 2).permissions(:manage_server).pm_enabled(false)
    .usage('feature <feature> <on/off/enable/disable>')
    .description('Enables (on) or Disables (off) the named Feature.')

  command(:loglevels, :show_log_levels)
    .owner_only(true).no_args.usage('loglevels')
    .description('Lists all log appenders and their logging levels.')

  command(:setloglevel, :set_log_level)
    .args_range(2, 2).owner_only(true)
    .usage('setloglevel <log_name> <log_level>')
    .description('Sets the logging level for the named appender to the given level.')

  command(:aliascmd, :alias_command)
    .args_range(2, 2).permissions(:manage_server).pm_enabled(false)
    .usage('aliascmd <command> <alias>')
    .description('Creates an alternate name for a command.')

  command(:clraliases, :clear_aliases)
    .no_args.permissions(:manage_server).pm_enabled(false).usage('clraliases')
    .description('Clears all command aliases.')

  command(:aliases, :list_aliases)
    .no_args.pm_enabled(false).usage('aliases')
    .description('Lists all command aliases.')

  event(:message, :alias_handler).pm_enabled(false)

  def redis_name
    :admin
  end

  def limit_command(_event, command, allow_deny, *channel_list)
    allow_deny = allow_deny.downcase
    return 'Second parameter must be one of the following: allow, deny, whitelist, blacklist.' unless %w[allow deny whitelist blacklist].include?(allow_deny)
    return "#{command} is not a recognized command." unless bot.commands.key?(command.to_sym)
    return 'You cannot limit that command' if command == 'limitcmd' || command == 'limitclr'

    if channel_list.first.casecmp?('role')
      limit_by_role(command, allow_deny, channel_list[1..-1].join(' '))
    else
      limit_by_channel(command, allow_deny, channel_list)
    end
  end

  def clear_command_limits(_event, command)
    return "'#{command}' is not a recognized command." unless bot.commands.key?(command.to_sym)

    limits_store.clear_limits(command)
    "All limits cleared for command '#{command}'"
  end

  def show_command_limits(event, command = nil)
    if command.nil?
      event.channel.start_typing
      return "Limited Commands: #{limits_store.limited_commands.join(', ')}"
    end

    return "'#{command}' is not a recognized command." unless bot.commands.key?(command.to_sym)

    <<~LIMITS
      Channels
        Whitelist: #{limits_store.whitelisted_channels(command).map { |id| bot.channel(id, server)&.name }.compact.join(', ')}
        Blacklist: #{limits_store.blacklisted_channels(command).map { |id| bot.channel(id, server)&.name }.compact.join(', ')}
      Roles
        Whitelist: #{limits_store.whitelisted_roles(command).map { |id| server.role(id)&.name }.compact.join(', ')}
        Blacklist: #{limits_store.blacklisted_roles(command).map { |id| server.role(id)&.name }.compact.join(', ')}
    LIMITS
  end

  def invite_url(_event)
    bot.invite_url(permission_bits: server&.bot&.highest_role&.permissions&.bits)
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

  def alias_command(_event, command_name, alias_name)
    return "#{command_name} is not a recognized command." unless bot.commands.key?(command_name.to_sym)
    return 'Alias must not match the command name.' if command_name.casecmp?(alias_name)
    return 'Alias cannot be the same as another command.' if bot.commands.key?(alias_name.to_sym)

    set_alias(command_name, alias_name)
    "**#{alias_name}** set as an alias for **#{command_name}**."
  end

  def clear_aliases(_event)
    delete_aliases
    'All command aliases have been removed.'
  end

  def list_aliases(_event)
    aliases = get_aliases
    return 'There are no command aliases on this server.' if aliases.empty?

    max_len = aliases.keys.map(&:length).max
    "```#{aliases.map { |a, c| "#{a.ljust(max_len)} => #{c}" }.join("\n")}```"
  end

  def alias_handler(event)
    return if event.from_bot?

    text = bot.prefix.call(event) # Strips prefix and returns remaining text
    return if text.nil? # Command prefix not present

    command_name, *args = text.split(' ')
    return if bot.commands.key?(command_name.to_sym)

    command = get_aliased_command(command_name)
    return if command.nil?

    Omnic.logger.info("Alias triggered: #{command_name}")
    result = command.call(event, args)
    return if result.nil?

    event.message.reply(result)
  end

  private

  ALIAS_KEY = 'alias'.freeze unless defined? ALIAS_KEY

  def feature_redis
    Redis::Namespace.new(get_server_namespace(@server), redis: Omnic.redis)
  end

  def limits_store
    @limits_store ||= LimitsStore.new(server_redis)
  end

  def limit_by_role(command, allow_deny, role_name)
    return 'Role name not provided.' if role_name.empty?

    found_role = server.roles.find { |r| r.name.casecmp?(role_name) }
    return "#{role_name} does not match any roles on this server." if found_role.nil?

    return whitelist_role(command, found_role.id) if is_whitelist(allow_deny)
    blacklist_role(command, found_role.id)
  end

  def limit_by_channel(command, allow_deny, channel_list)
    channels = channel_list.map { |channel| find_channel(channel) }
    not_found_channels = channels.select(&:failure?)
    return not_found_channels.map(&:error).join("\n") if not_found_channels.any?

    channel_ids = channels.map { |found_channel| found_channel.value.id }

    return whitelist_channels(command, channel_ids) if is_whitelist(allow_deny)

    blacklist_channels(command, channel_ids)
  end

  def whitelist_channels(command, channel_ids)
    limits_store.whitelist_channels(command, channel_ids)
    "#{channel_ids.count} channel#{channel_ids.count == 1 ? '' : 's'} added to whitelist for command #{command}"
  end

  def blacklist_channels(command, channel_ids)
    limits_store.blacklist_channels(command, channel_ids)
    "#{channel_ids.count} channel#{channel_ids.count == 1 ? '' : 's'} added to blacklist for command #{command}"
  end

  def whitelist_role(command, role_id)
    limits_store.whitelist_role(command, role_id)
    "1 role added to whitelist for command #{command}"
  end

  def blacklist_role(command, role_id)
    limits_store.blacklist_role(command, role_id)
    "1 role added to blacklist for command #{command}"
  end

  def is_whitelist(allow_deny)
    %w[allow whitelist].include?(allow_deny)
  end

  def set_alias(command_name, alias_name)
    server_redis.hset(ALIAS_KEY, alias_name, command_name)
  end

  def get_aliased_command(alias_name)
    command_name = server_redis.hget(ALIAS_KEY, alias_name)
    return nil if command_name.nil?

    bot.commands[command_name.to_sym]
  end

  def get_aliases
    server_redis.hgetall(ALIAS_KEY)
  end

  def delete_aliases
    server_redis.del(ALIAS_KEY)
  end
end
