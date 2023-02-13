# dice_function.rb
#
# AUTHOR::  Kyle Mullins

class DiceFunction
  def initialize(function, dice_expression)
    @function = function
    @dice_expression = dice_expression
  end

  def validate
    raise ParserError, 'Invalid expression' if @dice_expression.nil?
    raise ParserError, 'Invalid function' unless %w[min max avg].include?(@function.downcase)

    @dice_expression.validate
  end

  def eval
    @dice_expression.send(@function.downcase)
  end

  alias min eval
  alias max eval
  alias avg eval

  def eval_and_print
    func_value = eval
    "#{print_eval} = #{func_value}"
  end

  def print
    "#{@function}(#{@dice_expression.print})"
  end

  def print_eval
    "#{@function}(#{@dice_expression.print_eval})"
  end

  def to_s
    "DiceFunction(#{@function} #{@dice_expression})"
  end
end
