# constant_value.rb
#
# Author::  Kyle Mullins

require_relative 'parser_error'

class ConstantValue
  def initialize(value)
    @value = value
  end

  def validate
    Integer(@value)
  rescue ArgumentError
    raise ParserError, "#{@value} is not a valid Integer"
  end

  def eval
    @value.to_i
  end

  def print
    @value.to_i
  end

  alias print_eval print
  alias eval_and_print print

  def to_s
    "ConstantValue(#{@value})"
  end
end
