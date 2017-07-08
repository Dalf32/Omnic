# simple_expression.rb
#
# Author::  Kyle Mullins

class SimpleExpression
  def initialize(left_expr, operator, right_expr)
    @left_expr = left_expr
    @operator = operator
    @right_expr = right_expr
  end

  def validate
    raise ParserError, 'Invalid expression' if @left_expr.nil? || @operator.nil? || @right_expr.nil?

    @left_expr.validate
    @operator.validate
    @right_expr.validate
  end

  def eval
    @operator.eval(@left_expr.eval, @right_expr.eval)
  end

  def print
    "(#{@left_expr.print} #{@operator.print} #{@right_expr.print})"
  end

  def print_eval
    "(#{@left_expr.print_eval} #{@operator.print_eval} #{@right_expr.print_eval})"
  end

  def to_s
    "SimpleExpression(#{@left_expr} #{@operator} #{@right_expr})"
  end
end
