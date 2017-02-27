# command_handler.rb
#
# Author::	Kyle Mullins

require_relative '../model/feature'

class CommandHandler
  def self.command(command, command_method, **args)
    limit_action = args.dig(:limit, :action)
    args[:limit].delete(:action) unless limit_action.nil?

    pm_enabled = args[:pm_enabled] != false
    args.delete(:pm_enabled)

    cmd_feature = args[:feature]
    args.delete(:feature)

    Omnic.features[cmd_feature].add_command(command) if Omnic.features.has_key?(cmd_feature)

    if args.has_key?(:limit)
      Omnic.rate_limiter.bucket(command, **(args[:limit]))
    end

    Omnic.bot.command command, **args do |triggering_event, *other_args|
      Omnic.logger.info("Command triggered: #{command} #{other_args.join(' ')}")
      Omnic.logger.debug("  Context: Server #{format_obj(triggering_event.server)}; Channel #{format_obj(triggering_event.channel)}; Author #{format_obj(triggering_event.author)}; PM? #{is_pm?(triggering_event)}")

      if is_pm?(triggering_event) && !pm_enabled
        Omnic.logger.debug('  Command not run because it is not allowed in PMs')
        triggering_event.message.reply("Command #{command} cannot be used in DMs.")
        return
      end

      unless feature_enabled?(Omnic.features[cmd_feature], triggering_event)
        Omnic.logger.debug('  Command not run because the feature is not enabled on this server')
        return
      end

      unless command_allowed?(command, triggering_event)
        Omnic.logger.debug('  Command not run because it is not allowed in this channel')
        triggering_event.message.reply("Command #{command} is not allowed in this channel.")
        return
      end

      handler = create_handler(triggering_event)
      limit_scope = get_server(triggering_event) || get_user(triggering_event)
      time_remaining = Omnic.rate_limiter.rate_limited?(command, limit_scope)

      if time_remaining #This will be false when not rate limited
        Omnic.logger.debug('  Command was rate limited')
        handler.send(limit_action, triggering_event, time_remaining) unless limit_action.nil?
      else
        handler.send(command_method, triggering_event, *other_args)
      end
    end
  end

  def self.event(event, event_method, *args)
    Omnic.bot.public_send(event, *args) do |triggering_event, *other_args|
      Omnic.logger.info("Event triggered: #{event}")

      handler = create_handler(triggering_event)
      handler.send(event_method, triggering_event, *other_args)
    end
  end

  def self.feature(name, default_enabled: true)
    Omnic.features[name] = Feature.new(name, default_enabled)
  end

  def initialize(bot, server, user)
    @bot = bot
    @server = server
    @user = user
  end

  protected
  attr_accessor :bot

  def thread(thread_name, &block)
    existing_thread = Omnic.get_worker_thread(thread_name)
    return existing_thread unless existing_thread.nil?
    return nil unless block_given?

    Omnic.create_worker_thread(thread_name, &block)
  end

  def global_redis
    get_redis_namespace(self, 'GLOBAL')
  end

  def server_redis
    get_redis_namespace(self, CommandHandler.get_server_namespace(@server)) unless @server.nil?
  end

  def user_redis
    get_redis_namespace(self, CommandHandler.get_user_namespace(@user)) unless @user.nil?
  end

  def config
    get_config_section(self)
  end

  def log
    Omnic.logger
  end

  def self.is_pm?(message_event)
    message_event.server.nil?
  end

  private

  def self.create_handler(triggering_event)
    self.new(Omnic.bot, get_server(triggering_event), get_user(triggering_event))
  end

  def self.feature_enabled?(feature, triggering_event)
    return true if feature.nil?

    server = get_server(triggering_event)
    return true if server.nil?

    return feature.enabled?(Redis::Namespace.new(get_server_namespace(server), redis: Omnic.redis))
  end

  def self.command_allowed?(command, triggering_event)
    server = get_server(triggering_event)
    return true if server.nil?

    key_template = "#{get_server_namespace(server)}:admin:%{type}:#{command.to_s}"
    channel_whitelist_key = key_template % { type: 'channel_whitelist' }
    channel_blacklist_key = key_template % { type: 'channel_blacklist' }
    channel = get_channel(triggering_event)

    unless channel.nil?
      if Omnic.redis.exists(channel_whitelist_key) &&
          !Omnic.redis.sismember(channel_whitelist_key, channel.id.to_s)
        return false
      elsif Omnic.redis.exists(channel_blacklist_key) &&
          Omnic.redis.sismember(channel_blacklist_key, channel.id.to_s)
        return false
      end
    end

    true
  end

  def self.get_server(triggering_event)
    if triggering_event.respond_to?(:server) && !triggering_event.server.nil?
      triggering_event.server
    elsif triggering_event.respond_to?(:channel) && !triggering_event.channel.server.nil?
      triggering_event.channel.server
    end
  end

  def self.get_server_namespace(server)
    "SERVER:#{server.id.to_s}"
  end

  def self.get_channel(triggering_event)
    triggering_event.respond_to?(:channel) ? triggering_event.channel : nil
  end

  def self.get_user(triggering_event)
    if triggering_event.respond_to?(:author) && !triggering_event.author.nil?
      triggering_event.author
    elsif triggering_event.respond_to?(:user) && !triggering_event.user.nil?
      triggering_event.user
    end
  end

  def self.get_user_namespace(user)
    "USER:#{user.id.to_s}"
  end

  def self.format_obj(obj)
    return '' if obj.nil?

    "[#{obj.name}:#{obj.id}]"
  end

  def get_config_section(handler)
    Omnic.config.handlers[handler.config_name] if handler.respond_to? :config_name
  end

  def get_redis_namespace(handler, namespace_id)
    Redis::Namespace.new(namespace_id + ':' + handler.redis_name.to_s, redis: Omnic.redis) if handler.respond_to? :redis_name
  end
end
