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
      cmd.other_params(args)
      Omnic.commands << cmd
    end
  end

  def self.event(event, event_method, **args)
    OmnicEvent.new(self, event, event_method).tap do |evt|
      evt.other_params(args)
      Omnic.events << evt
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
    redis_namespace(self, 'GLOBAL')
  end

  def server_redis
    redis_namespace(self, get_server_namespace(@server)) unless @server.nil?
  end

  def user_redis
    redis_namespace(self, get_user_namespace(@user)) unless @user.nil?
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

  private

  def config_section(handler)
    return nil unless handler.respond_to? :config_name

    Omnic.config.handlers[handler.config_name]
  end

  def redis_namespace(handler, namespace_id)
    return nil unless handler.respond_to? :redis_name

    Redis::Namespace.new("#{namespace_id}:#{handler.redis_name}",
                         redis: Omnic.redis)
  end

  def search_channels(channel_text)
    @bot.find_channel(channel_text, @server.name, type: 0)
  end

  def search_users(user_text)
    if /<@\d+>/.match?(user_text)
      [@server.member(@bot.parse_mention(user_text).id)]
    elsif user_text.include?('#')
      @server.members.find_all { |member| member.distinct == user_text }
    else
      @server.members.find_all do |member|
        member.nick&.casecmp(user_text.downcase)&.zero? ||
          member.username.casecmp(user_text.downcase).zero?
      end
    end
  end
end
