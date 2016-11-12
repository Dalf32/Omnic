# command_handler.rb
#
# Author::	Kyle Mullins

class CommandHandler
  def self.command(command, command_method, **args)
    limit_action = args.dig(:limit, :action)
    args[:limit].delete(:action) unless limit_action.nil?

    if args.has_key?(:limit)
      Omnic.rate_limiter.bucket(command, **(args[:limit]))
    end

    Omnic.bot.command command, **args do |triggering_event, *other_args|
      handler = create_handler(triggering_event)
      limit_scope = get_server(triggering_event) || get_user(triggering_event)
      time_remaining = Omnic.rate_limiter.rate_limited?(command, limit_scope)

      if time_remaining #This will be false when not rate limited
        handler.send(limit_action, triggering_event, time_remaining) unless limit_action.nil?
      else
        handler.send(command_method, triggering_event, *other_args)
      end
    end
  end

  def self.event(event, event_method, *args)
    Omnic.bot.public_send(event, *args) do |triggering_event, *other_args|
      handler = create_handler(triggering_event)
      handler.send(event_method, triggering_event, *other_args)
    end
  end

  def initialize(bot, server, user)
    @bot = bot
    @server = server
    @user = user
  end

  protected
  attr_accessor :bot

  def thread(&block)
    Omnic.create_worker_thread(&block)
  end

  def global_redis
    get_redis_namespace(self, 'GLOBAL')
  end

  def server_redis
    get_redis_namespace(self, 'SERVER:' + @server.id.to_s) unless @server.nil?
  end

  def user_redis
    get_redis_namespace(self, 'USER:' + @user.id.to_s) unless @user.nil?
  end

  def config
    get_config_section(self)
  end

  def log
    Omnic.logger
  end

  private

  def self.create_handler(triggering_event)
    self.new(Omnic.bot, get_server(triggering_event), get_user(triggering_event))
  end

  def self.get_server(triggering_event)
    if triggering_event.respond_to?(:server) &&triggering_event.server.nil?
      triggering_event.server
    elsif triggering_event.respond_to?(:channel) && !triggering_event.channel.server.nil?
      triggering_event.channel.server
    end
  end

  def self.get_user(triggering_event)
    if triggering_event.respond_to?(:author) && !triggering_event.author.nil?
      triggering_event.author
    elsif triggering_event.respond_to?(:user) && !triggering_event.user.nil?
      triggering_event.user
    end
  end

  def get_config_section(handler)
    Omnic.config.handlers[handler.config_name] if handler.respond_to? :config_name
  end

  def get_redis_namespace(handler, namespace_id)
    Redis::Namespace.new(namespace_id + ':' + handler.redis_name.to_s, redis: Omnic.redis) if handler.respond_to? :redis_name
  end
end
