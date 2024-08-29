# command_handler.rb
#
# Author::  Kyle Mullins

require_relative '../model/feature'
require_relative '../model/omnic_command'
require_relative '../model/omnic_event'
require_relative '../model/command_helper'
require_relative '../model/result'

class CommandHandler
  include CommandHelper

  def self.command(command, command_method, **args)
    OmnicCommand.new(self, command, command_method).tap do |cmd|
      cmd.other_params(**args)
      Omnic.commands << cmd
    end
  end

  def self.event(event, event_method, **args)
    OmnicEvent.new(self, event, event_method).tap do |evt|
      evt.other_params(**args)
      Omnic.events << evt
    end
  end

  def self.feature(name, default_enabled: true, description: '')
    Omnic.features[name] = Feature.new(name, default_enabled, description)
  end

  def self.cache_object(key, create_method)
    CommandHandler.cached_objects[cache_key(self, key)] = create_method
  end

  def self.cache_key(calling_class, key)
    "#{calling_class.name}//#{key}"
  end

  def self.cached_objects
    @cached_objects ||= {}
  end

  def initialize(bot, server, user)
    @bot = bot
    @server = server
    @user = user
  end

  protected

  attr_accessor :bot, :server, :user

  def thread(thread_name, &block)
    existing_thread = Omnic.get_worker_thread(thread_name)
    return existing_thread unless existing_thread.nil?
    return nil unless block_given?

    Omnic.create_worker_thread(thread_name, &block)
  end

  def global_redis
    redis_namespace(self, 'GLOBAL')
  end

  def server_redis(server = @server)
    redis_namespace(self, get_server_namespace(server)) unless server.nil?
  end

  def user_redis(user = @user)
    redis_namespace(self, get_user_namespace(user)) unless user.nil?
  end

  def config
    config_section(self)
  end

  def log
    Omnic.logger
  end

  def find_channel(channel_text)
    channels = search_channels(channel_text)
    result = Result.new

    result.error = "#{channel_text} does not match any channels on this server" if channels.empty?
    result.error = "#{channel_text} matches more than one channel on this server" if channels.count > 1

    result.value = channels.first if result.success?
    result
  end

  def find_user(user_text)
    users = search_users(user_text)
    result = Result.new

    result.error = "#{user_text} does not match any members of this server" if users.empty?
    result.error = "#{user_text} matches multiple members of this server" if users.count > 1

    result.value = users.first if result.success?
    result
  end

  def handle_errors(event)
    begin
      yield
    rescue StandardError => err
      log.error(err)
      event.respond('An unexpected error occurred.')
    end
  end

  def update_bot_status(status, activity, url, *args)
    priority = determine_status_priority
    cur_prio = current_status_priority

    if cur_prio > priority
      log.debug("Bot status was not set by #{self.class} (priority #{priority}) because it has already been set with a higher priority (#{cur_prio})")
      return
    end

    log.debug("Bot status set by #{self.class} (priority #{priority})")
    Omnic.redis.set(PRIO_KEY, priority)
    Omnic.bot.update_status(status, activity, url, *args)
  end

  def clear_bot_status
    priority = determine_status_priority
    cur_prio = current_status_priority

    if cur_prio > priority
      log.debug("Bot status was not cleared by #{self.class} (priority #{priority}) because it was set with a higher priority (#{cur_prio})")
      return
    end

    log.debug("Bot status cleared by #{self.class} (priority #{priority})")
    Omnic.redis.del(PRIO_KEY)
    Omnic.bot.update_status('online', nil, nil, 0, false, 0)
  end

  def cached_object(key, expiration_s = nil)
    cache_key = CommandHandler.cache_key(self.class, key)
    return nil unless CommandHandler.cached_objects.key?(cache_key)
    return Omnic.cache[cache_key] if Omnic.cache.key?(cache_key)

    log.debug("Object with key #{cache_key} is not present in cache, creating a new one")
    new_obj = self.send(CommandHandler.cached_objects[cache_key])
    if expiration_s.nil?
      Omnic.cache[cache_key] = new_obj
    else
      Omnic.cache.put(cache_key, new_obj, expiration_s)
    end
  end

  private

  PRIO_KEY = "GLOBAL:bot_status_prio" unless defined? PRIO_KEY

  def config_section(handler)
    return nil unless handler.respond_to?(:config_name)

    Omnic.config.handlers[handler.config_name]
  end

  def redis_namespace(handler, namespace_id)
    return nil unless handler.respond_to?(:redis_name)

    Redis::Namespace.new("#{namespace_id}:#{handler.redis_name}",
                         redis: Omnic.redis)
  end

  def search_channels(channel_text)
    @bot.find_channel(channel_text, @server.name, type: 0)
  end

  def search_users(user_text)
    mention = @bot.parse_mention(user_text)

    if !mention.nil?
      [@server.member(mention.id)]
    elsif user_text.include?('#')
      @server.members.find_all { |member| member.distinct == user_text }
    else
      @server.members.find_all do |member|
        member.nick&.casecmp(user_text)&.zero? ||
          member.username.casecmp(user_text).zero?
      end
    end
  end

  def determine_status_priority
    priorities = Omnic.config.status_priority
    respond_to?(:config_name) ? priorities.fetch(config_name, 0) : 0
  end

  def current_status_priority
    Omnic.redis.exists?(PRIO_KEY) ? Omnic.redis.get(PRIO_KEY).to_i : 0
  end
end
