# Config

configure do |config|
  config.bot_token = '<bot_token>>'
  config.client_id = '<client_id>'
  config.command_prefix = '!'
  config.advanced_commands = false

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

  config.restart_on_error = true

  config.redis do |redis|
    redis.url = 'redis://127.0.0.1:6379/0'
    redis.timeout = 2
  end

  config.handlers_list = [
    'omnic/handlers/greeting_handler.rb',
    'omnic/handlers/echo_handler.rb',
    'omnic/handlers/admin_functions_handler.rb',
    'omnic/handlers/help_handler.rb'
  ]

  config.handlers.echo do |echo|
    echo.prefix = '~'
  end
end
