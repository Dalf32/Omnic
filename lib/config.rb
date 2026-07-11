# Config

configure do |config|
  config.bot_token = '' # Discord bot token
  config.client_id = 0 # Discord application id
  config.command_prefix = '!'
  config.advanced_commands = false
  config.owner_id = 0 # Bot owner Discord user id
  config.restart_on_error = true

  config.logging do |log|
    log.format = "[%d %5l] %m\n"
    log.date_format = '%Y-%m-%d %H:%M:%S'

    log.stdout do |stdout|
      stdout.enabled = true
      stdout.level = :info
    end

    log.file do |file|
      file.enabled = true
      file.path = 'omnic.log'
      file.level = :debug
      file.rolling = true
      file.rolling_name = 'date' # Can be 'date' or 'number'
      file.roll_age = 'daily' # Can be a number of seconds or one of 'daily', 'weekly', or 'monthly'
      file.roll_size = 1_048_576 # Size in bytes, either this or roll_age must be specified
      file.files_to_keep = 7
    end
  end

  config.redis do |redis|
    redis.url = 'redis://127.0.0.1:6379/0' # Change if not locally-hosted redis
    redis.timeout = 2
  end

  config.encryption do |encrypt|
    encrypt.private_key = '' # Certificate key needed primarily for auditing
  end

  config.handlers_list = %w[
    omnic/core_handlers.rb
    omnic/extra_handlers.rb
  ]

  config.plugins_list %w[]

  config.handlers.echo do |echo|
    echo.prefix = '~'
  end

  config.handlers.reminders do |reminders|
    reminders.sleep_interval = 1
    reminders.max_response_time = 30
  end

  config.handlers.audit do |audit|
    audit.message_cache_time = 120 # Time in minutes to keep messages cached, 0 to not cache messages at all
  end
end
