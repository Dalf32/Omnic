#Config

configure do |config|
  config.bot_token = '<bot_token>>'
  config.client_id = '<client_id>'
  config.command_prefix = '!'
  config.advanced_commands = true

  config.log_level = 'INFO'
  config.log_format = "[%{datetime} %{severity}] %{message}\n"
  config.date_format = '%Y-%m-%d %H:%M:%S'

  config.restart_on_error = true

  #config.roles.bot_admin = '' Not used at this time

  config.redis do |redis|
    redis.url = 'redis://127.0.0.1:6379/0'
    redis.timeout = 2
  end

  config.handlers_list = [
      'omnic/handlers/greeting_handler.rb'
  ]
end
