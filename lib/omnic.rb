# omnic.rb
#
# Author::  Kyle Mullins

require 'discordrb'
require 'configatron/core'
require 'redis'
require 'redis/namespace'
require 'logger'
require_relative 'omnic/handlers/command_handler'

module Omnic
  def self.config
    @@config ||= Configatron::RootStore.new
  end

  def self.bot
    @@bot ||= Discordrb::Commands::CommandBot.new(token: config.bot_token, client_id: config.client_id, prefix: config.command_prefix)
  end

  def self.redis
    @@redis ||= setup_redis
  end

  def self.rate_limiter
    @@rate_limiter ||= Discordrb::Commands::SimpleRateLimiter.new
  end

  def self.logger
    @@logger ||= init_logger
  end

  def self.load_configuration
    load 'config.rb'
    Omnic.config.handlers_list.each do |handler_file|
      begin
        load handler_file
      rescue StandardError => e
        logger.warn("Failed to load handler file #{handler_file}: #{e}\n\t#{e.backtrace.join("\n\t")}")
      end
    end
  end

  def self.create_worker_thread(&block)
    Thread.new(&block).tap{ |thread| thread_list << thread }
  end

  def self.kill_worker_threads
    thread_list.each do |thread|
      thread.kill
      thread.join
    end

    thread_list.clear
  end

  private

  def self.thread_list
    @@thread_list ||= []
  end

  def self.setup_redis
    if config.redis.has_key?(:url)
      params = { url: config.redis.url }
      params[:timeout] = config.redis.timeout if config.redis.has_key?(:timeout)

      Redis.new(**params)
    end
  end

  def self.init_logger
    Logger.new(STDOUT).tap do |log|
      log.level = config.has_key?(:log_level) ? config.log_level : Logger::INFO
      log.formatter = proc do |severity, datetime, progname, message|
        formatted_datetime = config.has_key?(:date_format) ? datetime.strftime(config.date_format) : datetime
        format = config.has_key?(:log_format) ? config.log_format : "%{datetime} %{severity} - %{message}\n"
        format % { severity: severity, datetime: formatted_datetime, progname: progname, message: message }
      end
    end
  end
end

def configure
  yield Omnic.config
end

#Main
should_restart = false

begin
  Omnic.load_configuration
  Omnic.redis.ping
  Omnic.logger.info('Connected to Redis') if Omnic.redis.connected?

  Omnic.logger.info('Starting bot...')
  Omnic.bot.run(:async)
  Omnic.logger.info('Started.')

  should_quit = false

  until should_quit
    print '>> '
    input = gets.chomp

    case input
      when 'quit', 'close', 'exit', 'stop'
        should_quit = true
        should_restart = false
        break
      when 'restart'
        should_quit = true
        should_restart = true
        break
      when 'commands'
        puts "Loaded commands: #{Omnic.bot.commands.keys.join(', ')}"
      when 'servers'
        puts "Connected servers: #{Omnic.bot.servers.values.map(&:name).join(', ')}"
      when 'threads'
        puts "Live threads: #{Thread.list.count}"
    end
  end
rescue StandardError => e
  Omnic.logger.error(e)
  should_restart = Omnic.config.restart_on_error
ensure
  Omnic.logger.info('Stopping bot...')
  Omnic.kill_worker_threads
  Omnic.bot.gateway.kill
  Omnic.bot.sync
  Omnic.bot.clear!
  Omnic.logger.info('Stopped.')
end while should_restart

puts 'Goodbye!'
