# binary_operator.rb
#
# Author::  Kyle Mullins

class BinaryOperator
  def initialize(operator)
    @operator = operator
  end

  def validate
  end

  def eval(left_val, right_val)
    left_val.send(@operator, right_val)
  end

  def print
    @operator
  end

  alias :print_eval :print

  def to_s
    "BinaryOperator(#{@operator})"
  end
end
