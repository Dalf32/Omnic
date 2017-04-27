# help_handler.rb
#
# Author::	Kyle Mullins

class HelpHandler < CommandHandler
  command :help, :show_help, max_args: 1, description: 'Displays this help text'

  def show_help(_event, *command_name)
    commands_list = bot.commands

    return show_command_help(commands_list, command_name.first) unless command_name.empty?

    command_list = commands_list.select { |cmd_pair| command_enabled?(cmd_pair) }
                                .map { |cmd_pair| "`#{cmd_pair.first}`" }.join(', ')
    "**Available commands:**\n#{command_list}"
  end

  def show_command_help(commands_list, command_name)
    command = commands_list.detect { |cmd_pair| cmd_pair.first.to_s == command_name }

    return "No command called #{command_name}" if command.nil?

    return nil unless command_enabled?(command_name)

    "``#{command_name}``: #{command.last.attributes[:description]}"
  end

  private

  def find_command_feature(command_name)
    Omnic.features.values.find { |f| f.has_command?(command_name.to_sym) }
  end

  def command_enabled?(command_name)
    return true if @server.nil?

    feature = find_command_feature(command_name)

    return true if feature.nil?

    server_redis = Redis::Namespace.new(CommandHandler.get_server_namespace(@server), redis: Omnic.redis)
    feature.enabled?(server_redis)
  end
end
