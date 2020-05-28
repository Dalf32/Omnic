# echo_handler.rb
#
# Author::  Kyle Mullins

require_relative 'echo/command_store'
require_relative 'echo/command_html_renderer'

class EchoHandler < CommandHandler
  feature :echo, default_enabled: true,
                 description: 'Allows for storage and recall of arbitrary text.'

  event(:message, :on_message)
    .feature(:echo).pm_enabled(false)

  command(:addcmd, :add_command)
    .min_args(2).pm_enabled(false).feature(:echo)
    .usage('addcmd <command> <output>')
    .description('Adds an echo that the bot will reply with when it receives the command trigger. "$#" can be used to add a placeholder in the output.')

  command(:delcmd, :delete_command)
    .args_range(1, 1).pm_enabled(false).feature(:echo).usage('delcmd <command>')
    .description('Deletes the echo command of the given name.')

  command(:listcmds, :list_commands)
    .pm_enabled(false).feature(:echo).usage('listcmds [filter]')
    .description('Lists all the registered echo commands.')

  command(:delall, :delete_all)
    .permissions(:administrator).pm_enabled(false).feature(:echo)
    .usage('delall').description('Deletes all of the registered echo commands.')

  # command(:previewcmds, :preview_commands)
  #   .pm_enabled(false).feature(:echo).no_args.usage('previewcmds')
  #   .limit(delay: 60, action: :on_limit).description('')

  def config_name
    :echo
  end

  def redis_name
    :echo
  end

  def add_command(_event, command, *output)
    is_edit = command_store.has_command?(command)
    command_store.add_command(command, output.join(' '))

    (is_edit ? 'Command edited: ' : 'Command added: ') + "#{config.prefix}#{command}"
  end

  def delete_command(_event, command)
    return "No command matching #{config.prefix}#{command}" unless command_store.has_command?(command)

    command_store.remove_command(command)
    "Command deleted: #{config.prefix}#{command}"
  end

  def list_commands(event, *filter)
    commands = command_store.command_names

    return 'No commands yet!' if commands.empty?

    filtered_cmds = filter.empty? ? commands : commands.select { |cmd| cmd.include?(filter.first) }

    return 'No commands matching filter.' if filtered_cmds.empty?

    total = 0
    cmds = filtered_cmds.each_slice(3)
                        .map { |command_row| format_cmd_row(command_row) }
                        .map { |row_text| [row_text, total += row_text.length] }
                        .slice_when { |p1, p2| p1.last / 1900 < p2.last / 1900 }
                        .map { |list_split| list_split.map(&:first) }
                        .map { |list_split| list_split.join(' ') }

    first_msg_text = (filter.empty? ? '' : "Filter: #{filter.first}\n") + cmds[0]
    event.message.reply("***Available Commands***\n```#{first_msg_text}```")

    cmds[1..-1].each { |cmd| event.message.reply("```#{cmd}```") }

    nil
  end

  def delete_all(event)
    event.message.reply('This will delete all commands, are you sure? (y/n)')

    confirmation_text = event.message.await!(start_with: /[yn]/i).text

    unless %w[y yes].include?(confirmation_text.downcase)
      return 'Ok, commands will not be cleared.'
    end

    command_store.clear_commands
    'All commands cleared.'
  end

  def preview_commands(event)
    template_file = __dir__ + '/echo/command_list_template.html.erb'

    renderer = CommandHtmlRenderer.new(template_file)
                                  .command_prefix(config.prefix)
                                  .server_name(event.server.name)
                                  .commands(command_store.commands)
                                  .users(event.server.members)

    Tempfile.open(%w[command_list_ .html]) do |outfile|
      outfile.write(renderer.render)
      event.channel.send_file(outfile.open)
    end

    nil
  end

  def on_message(event)
    text = event.message.text
    match = text.match(/[^#{config.prefix}]*(#{config.prefix}+\w*)(.*)/)
    return if match.nil?

    full_command = match[1]
    command_name = full_command.delete(config.prefix)

    return unless command_store.has_command?(command_name)

    message = command_store.get_reply(command_name).gsub('$#', '%s')
    placeholder_count = message.scan(/%s/).count
    args = match[2].split(' ')
    args += [''] * [(placeholder_count - args.count), 0].max

    event.message.reply(format(message, *args))
    event.message.delete if full_command.start_with?(config.prefix * 2)
  end

  def on_limit(event, time_remaining)
    time_remaining = time_remaining.ceil
    message = "Hold your horses! Wait #{time_remaining} more second#{time_remaining == 1 ? '' : 's'} then try again."
    bot.send_temporary_message(event.message.channel.id, message, time_remaining + 2)

    nil
  end

  private

  def command_store
    @command_store ||= CommandStore.new(server_redis)
  end

  def format_cmd_row(command_row)
    command_row.map { |command| format_listed_cmd(command) }.join(' ') + "\n"
  end

  def format_listed_cmd(command)
    format("#{config.prefix}%-16s", command)
  end
end
