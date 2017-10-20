# echo_command.rb
#
# Author::  Kyle Mullins

class EchoCommand
  attr_reader :name, :reply

  def initialize(name, reply)
    @name = name
    @reply = reply
  end
end
