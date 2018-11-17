# omnic.rb
#
# Author::  Kyle Mullins

begin
  load 'rbnacl_conf.rb'
rescue LoadError
  # We are ok if this file doesn't exist, it is only needed if you want to use voice functionality
end

require 'discordrb'
require 'configatron/core'
require 'redis'
require 'redis/namespace'
require 'logging'

require_relative 'omnic/handlers/command_handler'
require_relative 'omnic/ext/bot_ext'
require_relative 'omnic/ext/role_ext'
require_relative 'omnic/ext/permissions_ext'
require_relative 'omnic/ext/logger_hook'
require_relative 'omnic/ext/syslog'

module Omnic
  def self.config
    @config ||= default_config
  end

  def self.bot
    attributes = {
      token: config.bot_token, client_id: config.client_id,
      prefix: config.command_prefix,
      advanced_functionality: config.advanced_commands, help_command: false,
      no_permission_message: "I don't have permission to perform that action on this Server."
    }

    @bot ||= Discordrb::Commands::CommandBot.new(attributes)
  end

  def self.redis
    @redis ||= setup_redis
  end

  def self.rate_limiter
    @rate_limiter ||= Discordrb::Commands::SimpleRateLimiter.new
  end

  def self.logger
    @logger ||= init_logger
  end

  def self.features
    @features ||= {}
  end

  def self.load_configuration(config_file)
    begin
      load config_file
    rescue LoadError, StandardError => e
      logger.fatal("Failed to load configuration file #{config_file}: #{e}\n\t#{e.backtrace.join("\n\t")}")
      return false
    end

    load_handlers
    load_commands
    load_events

    true
  end

  def self.shutdown
    kill_worker_threads
    commands.clear
    events.clear
    bot.clear!
    bot.gateway.kill
    bot.sync
  end

  def self.create_worker_thread(thread_name, &block)
    Thread.new(&block).tap { |thread| thread_list[thread_name] = thread }
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

  def self.clear_features
    features.clear
  end

  def self.commands
    @commands ||= []
  end

  def self.events
    @events ||= []
  end

  def self.encryption
    key = config.encryption.private_key

    return nil unless defined? RbNaCl::Sodium::Version::STRING
    return nil if key.nil? || key.empty?

    @encryption ||= RbNaCl::SimpleBox.from_secret_key(key.force_encoding(Encoding::BINARY))
  end

  # Private Class Methods

  def self.thread_list
    @thread_list ||= {}
  end

  def self.kill_worker_threads
    thread_list.values.each do |thread|
      thread.kill
      thread.join
    end

    thread_list.clear
  end

  def self.setup_redis
    return nil unless config.redis.key?(:url)

    params = { url: config.redis.url }
    params[:timeout] = config.redis.timeout if config.redis.key?(:timeout)

    Redis.new(**params)
  end

  def self.init_logger
    layout = Logging.layouts.pattern(pattern: config.logging.format,
                                     date_pattern: config.logging.date_format)

    Logging.logger['Omnic'].tap do |log|
      if config.logging.stdout.enabled
        stdout_log = Logging.appenders.stdout(layout: layout, level: config.logging.stdout.level)
        log.add_appenders(stdout_log)
      end

      if config.logging.file.enabled
        if config.logging.file.rolling
          rolling_opts = {
            layout: layout, level: config.logging.file.level,
            roll_by: config.logging.file.rolling_name,
            keep: config.logging.file.files_to_keep
          }

          rolling_opts[:age] = config.logging.file.roll_age if config.logging.file.key?(:roll_age)
          rolling_opts[:size] = config.logging.file.roll_size if config.logging.file.key?(:roll_size)

          file_log = Logging.appenders.rolling_file(config.logging.file.path,
                                                    **rolling_opts)
        else
          file_log = Logging.appenders.file(config.logging.file.path,
                                            layout: layout,
                                            level: config.logging.file.level)
        end

        log.add_appenders(file_log)
      end

      if config.logging.syslog.enabled
        syslog_log = Logging.appenders.syslog(**config.logging.syslog,
                                              layout: layout,
                                              level: config.logging.syslog.level)
        log.add_appenders(syslog_log)
      end
    end
  end

  def self.default_config
    config = Configatron::RootStore.new
    config.command_prefix = '!'
    config.advanced_commands = false
    config.handlers_list = []
    config.restart_on_error = true
    config.logging do |log|
      log.date_format = '%Y-%m-%d %H:%M:%S'
      log.format = "[%d %5l] %m\n"
      log.stdout do |stdout|
        stdout.enabled = true
        stdout.level = :info
      end

      log.file do |file|
        file.enabled = false
        file.level = :info
        file.path = 'omnic.log'
        file.rolling = false
      end

      log.syslog do |syslog|
        syslog.enabled = false
        syslog.level = :info
        syslog.hostname = 'localhost'
        syslog.port = 80
        syslog.local_hostname = nil
        syslog.tag = File.basename($PROGRAM_NAME)
      end
    end

    config
  end

  def self.load_handlers
    config.handlers_list.each do |handler_file|
      begin
        load handler_file
        logger.debug("Successfully loaded #{handler_file}")
      rescue LoadError, StandardError => e
        logger.warn("Failed to load handler file #{handler_file}: #{e}\n\t#{e.backtrace.join("\n\t")}")
      end
    end
  end

  def self.load_commands
    commands.map do |cmd|
      begin
        cmd.register
      rescue StandardError => e
        Omnic.logger.error("Failed to register #{cmd.handler_class} Command #{cmd.name}, #{e.message}")
      end
    end
  end

  def self.load_events
    events.map do |evt|
      begin
        evt.register
      rescue StandardError => e
        Omnic.logger.error("Failed to register #{evt.handler_class} Event #{evt.event}, #{e.message}")
      end
    end
  end

  private_class_method :thread_list, :setup_redis, :init_logger,
                       :default_config, :load_handlers, :kill_worker_threads
end

def configure
  yield Omnic.config
end

# Main
should_restart = false

Discordrb::Bot.prepend(BotExt)
Discordrb::Permissions.extend(PermissionsExt)
Discordrb::Logger.prepend(LoggerHook)
Discordrb::Role.prepend(RoleExt)

config_file = ARGV.empty? ? 'config.rb' : ARGV[0]

begin
  init_completed = false

  break unless Omnic.load_configuration(config_file)
  Omnic.redis.ping
  Omnic.logger.info('Connected to Redis') if Omnic.redis.connected?

  Discordrb::LOGGER.backing_logger = Omnic.logger

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
      puts "Loaded commands: #{Omnic.commands.map(&:id).join(', ')}"
    when 'servers'
      puts "Connected servers: #{Omnic.bot.servers.values.map(&:name).join(', ')}"
    when 'threads'
      puts "Live threads: #{Thread.list.count}"
    when 'workers'
      puts "Alive workers: #{Omnic.alive_workers}\nDead workers: #{Omnic.dead_workers}"
    when 'features'
      puts "Features:\n  #{Omnic.features.values.join("\n  ")}"
    when 'appenders'
      puts "Logging Appenders:\n  #{Omnic.logger.appenders.join("\n  ")}"
    when 'invite'
      puts Omnic.bot.invite_url
    when 'events'
      puts "Registered events: #{Omnic.events.map(&:id).join(', ')}"
    else
      puts 'Unrecognized command.'
    end
  end
rescue StandardError => err
  Omnic.logger.error("#{err}\n\t#{err.backtrace.join("\n\t")}")
  should_restart = Omnic.config.restart_on_error
ensure
  if init_completed
    Omnic.logger.info('Stopping bot...')
    Omnic.shutdown
    Omnic.logger.info('Stopped.')
  end
end while should_restart

puts 'Goodbye!'
