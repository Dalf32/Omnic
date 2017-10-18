# command_store.rb
#
# Author::  Kyle Mullins

require 'redis-objects'

require_relative 'echo_command'

class CommandStore
  def initialize(server_redis)
    @redis = server_redis
    @command_names = Redis::Set.new([@redis.namespace, 'commands'])
  end

  def command_names
    @command_names.members.sort
  end

  def commands
    command_names.map { |cmd| EchoCommand.new(cmd, get_reply(cmd)) }
  end

  def has_command?(command)
    @command_names.include?(command)
  end

  def add_command(command, reply)
    @command_names.add(command)
    @redis.append(reply_key(command), reply)
  end

  def remove_command(command)
    @redis.del(reply_key(command))
    @command_names.delete(command)
  end

  def clear_commands
    @command_names.each { |command| remove_command(command) }
  end

  def get_reply(command)
    @redis.get(reply_key(command)).encode('utf-8-hfs', 'utf-8')
  end

  private

  def reply_key(command)
    "command_reply:#{command}"
  end
end
