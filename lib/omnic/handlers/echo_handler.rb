# echo_handler.rb
#
# Author::	Kyle Mullins

class EchoHandler < CommandHandler
  feature :echo, default_enabled: true

  event :message, :on_message, feature: :echo

  command :addcmd, :add_command, min_args: 2, pm_enabled: false,
      feature: :echo, usage: 'addcmd <command> <output>',
      description: 'Adds an echo command such that the bot will reply with the provided output when it receives the command trigger.'

  command :delcmd, :delete_command, min_args: 1, max_args: 1, pm_enabled: false,
      feature: :echo, usage: 'delcmd <command>',
      description: 'Deletes the echo command of the given name.'

  command :listcmds, :list_commands, pm_enabled: false, feature: :echo,
      usage: 'listcmds [filter]', description: 'Lists all the registered echo commands.'

  command :delall, :delete_all, required_permissions: [:administrator],
      pm_enabled: false, feature: :echo, usage: 'delall',
      description: 'Deletes all of the registered echo commands.'

  def config_name
    :echo
  end

  def redis_name
    :echo
  end

  def add_command(_event, command, *output)
    is_edit = server_redis.sismember(COMMAND_SET_KEY, command)
    server_redis.sadd(COMMAND_SET_KEY, command)
    server_redis.append(get_command_key(command), output.join(' '))
    (is_edit ? 'Command edited: ' : 'Command added: ') + "#{config.prefix}#{command}"
  end

  def delete_command(_event, command)
    return "No command matching #{config.prefix}#{command}" unless server_redis.sismember(COMMAND_SET_KEY, command)

    server_redis.del(get_command_key(command))
    server_redis.srem(COMMAND_SET_KEY, command)
    "Command deleted: #{config.prefix}#{command}"
  end

  def list_commands(event, *filter)
    commands = server_redis.smembers(COMMAND_SET_KEY)

    return 'No commands yet!' if commands.empty?

    filtered_cmds = filter.empty? ? commands : commands.select { |cmd| cmd.include?(filter.first) }

    return 'No commands matching filter.' if filtered_cmds.empty?

    total = 0
    cmds = filtered_cmds.sort.each_slice(3)
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

  def delete_all(_event)
    server_redis.smembers(COMMAND_SET_KEY).each do |command_name|
      server_redis.del(get_command_key(command_name))
    end

    server_redis.del(COMMAND_SET_KEY)

    'All commands cleared.'
  end

  def on_message(event)
    return if CommandHandler.pm?(event)

    text = event.message.text
    full_command = text.scan(/[^#{config.prefix}]*(#{config.prefix}+\w*).*/).flatten.first

    return nil if full_command.nil?

    command_name = full_command.delete(config.prefix)

    if server_redis.smembers(COMMAND_SET_KEY).include?(command_name)
      reply = server_redis.get(get_command_key(command_name))

      event.message.reply(reply.encode('utf-8-hfs', 'utf-8'))

      event.message.delete if full_command.start_with?(config.prefix * 2)
    end
  end

  private

  COMMAND_SET_KEY = 'commands'.freeze unless defined? COMMAND_SET_KEY
  COMMAND_REPLY_KEY = 'command_reply'.freeze unless defined? COMMAND_REPLY_KEY

  def get_command_key(command)
    COMMAND_REPLY_KEY + ':' + command
  end

  def format_cmd_row(command_row)
    command_row.map { |command| format_listed_cmd(command) }.join(' ') + "\n"
  end

  def format_listed_cmd(command)
    format("#{config.prefix}%-16s", command)
  end
end
