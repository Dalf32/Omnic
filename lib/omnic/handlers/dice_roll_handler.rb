# dice_roll_handler.rb
#
# Author::  Kyle Mullins

require_relative 'dice_roll/expression_builder'

class DiceRollHandler < CommandHandler
  command :roll, :roll_dice

  def roll_dice(_event, *dice_expr)
    expression = ExpressionBuilder.build(dice_expr.join)

    log.debug("Expression: #{expression}")

    rolled_value = expression.eval
    "Rolling #{dice_expr.join(' ')}```#{expression.print_eval} = #{rolled_value}```"
  rescue ParserError => err
    err.message
  rescue ZeroDivisionError
    'Cannot divide by 0'
  end
end