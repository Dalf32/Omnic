# help_handler.rb
#
# Author::	Kyle Mullins

class HelpHandler < CommandHandler
  command :help, :show_help, max_args: 1, description: 'Displays this help text'

  def show_help(_event, *command_name)
    #TODO: select commands available in this channel
    commands_list = bot.commands

    return show_command_help(commands_list, *command_name) unless command_name.empty?

    command_list = commands_list.map{ |cmd_pair| "`#{cmd_pair.first}`" }.join(', ')
    "**Available commands:**\n#{command_list}"
  end

  def show_command_help(commands_list, command_name)
    command = commands_list.detect{ |cmd_pair| cmd_pair.first.to_s == command_name }

    return "No command called #{command_name}" if command.nil?

    "``#{command_name}``: #{command.last.attributes[:description]}"
  end
end