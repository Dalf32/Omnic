# omnic.rb
#
# Author::  Kyle Mullins

begin
  load 'rbnacl_conf.rb'
rescue LoadError => e
  #We are ok if this file doesn't exist, it is only needed if you want to use voice functionality
end

require 'discordrb'
require 'configatron/core'
require 'redis'
require 'redis/namespace'
require 'logger'

require_relative 'omnic/handlers/command_handler'
require_relative 'omnic/ext/bot_ext'
require_relative 'omnic/ext/permissions_ext'

module Omnic
  def self.config
    @@config ||= default_config
  end

  def self.bot
    @@bot ||= Discordrb::Commands::CommandBot.new(token: config.bot_token, client_id: config.client_id, prefix: config.command_prefix,
        advanced_functionality: config.advanced_commands)
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

  def self.load_configuration(config_file)
    begin
      load config_file
    rescue LoadError, StandardError => e
      logger.fatal("Failed to load configuration file #{config_file}: #{e}\n\t#{e.backtrace.join("\n\t")}")
      return false
    end

    Omnic.config.handlers_list.each do |handler_file|
      begin
        load handler_file
      rescue StandardError => e
        logger.warn("Failed to load handler file #{handler_file}: #{e}\n\t#{e.backtrace.join("\n\t")}")
      end
    end

    true
  end

  def self.create_worker_thread(thread_name, &block)
    Thread.new(&block).tap{ |thread| thread_list[thread_name] = thread }
  end

  def self.kill_worker_threads
    thread_list.values.each do |thread|
      thread.kill
      thread.join
    end

    thread_list.clear
  end

  def self.get_worker_thread(thread_name)
    thread_list[thread_name]
  end

  def self.alive_workers
    thread_list.values.count(&:alive?)
  end

  def self.dead_workers
    thread_list.count - alive_workers
  end

  private

  def self.thread_list
    @@thread_list ||= {}
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
      log.level = config.log_level
      log.formatter = proc do |severity, datetime, progname, message|
        formatted_datetime = datetime.strftime(config.date_format)
        format = config.log_format
        format % { severity: severity, datetime: formatted_datetime, progname: progname, message: message }
      end
    end
  end

  def self.default_config
    config = Configatron::RootStore.new
    config.date_format = '%Y-%m-%d %H:%M:%S'
    config.log_format = "%{datetime} %{severity} - %{message}\n"
    config.command_prefix = '!'
    config.advanced_commands = false
    config.handlers_list = []
    config.log_level = Logger::INFO
    config.restart_on_error = true
    config
  end
end

def configure
  yield Omnic.config
end

#Main
should_restart = false

Discordrb::Bot.prepend(BotExt)
Discordrb::Permissions.extend(PermissionsExt)

config_file = ARGV.empty? ? 'config.rb' : ARGV[0]

begin
  init_completed = false

  break unless Omnic.load_configuration(config_file)
  Omnic.redis.ping
  Omnic.logger.info('Connected to Redis') if Omnic.redis.connected?

  Omnic.logger.info('Starting bot...')
  Omnic.bot.run(:async)
  Omnic.logger.info('Started.')

  init_completed = true
  should_quit = false

  until should_quit
    print '>> '
    input = STDIN.gets.chomp

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
      when 'workers'
        puts "Alive workers: #{Omnic.alive_workers}\nDead workers: #{Omnic.dead_workers}"
    end
  end
rescue StandardError => e
  Omnic.logger.error("#{e}\n\t#{e.backtrace.join("\n\t")}")
  should_restart = Omnic.config.restart_on_error
ensure
  if init_completed
    Omnic.logger.info('Stopping bot...')
    Omnic.kill_worker_threads
    Omnic.bot.gateway.kill
    Omnic.bot.sync
    Omnic.bot.clear!
    Omnic.logger.info('Stopped.')
  end
end while should_restart

puts 'Goodbye!'
