# RepeatExpression
#
# AUTHOR::  Kyle Mullins

class RepeatExpression
  def initialize(repeat_count_expr, expr = nil)
    @repeat_count_expr = repeat_count_expr
    @expr = expr
  end

  def set_expression(expr)
    @expr = expr
  end

  def validate
    raise ParserError, 'Invalid expression' if @expr.nil? || @repeat_count_expr.nil?

    @expr.validate
    @repeat_count_expr.validate
  end

  def eval
    if @repeated_expressions.nil?
      @repeated_expressions = @repeat_count_expr.eval.times.map { @expr.clone }
    end

    @repeated_expressions.map(&:eval)
  end

  def eval_and_print
    rolled_values = eval
    preamble = "Repeating #{@expr.print} #{@repeat_count_expr.eval_and_print} times\n"

    preamble + @repeated_expressions.count.times.map do |i|
      "#{@repeated_expressions[i].print_eval} = #{rolled_values[i]}"
    end.join("\n")
  end

  def print
    "(#{@expr.print}) Repeat #{@repeat_count_expr.print}"
  end

  def print_eval
    "(#{@expr.print_eval}) Repeat #{@repeat_count_expr.print_eval}"
  end

  def to_s
    "RepeatExpression(#{@expr} Repeat #{@repeat_count_expr})"
  end

  def clone
    RepeatExpression.new(@repeat_count_expr.clone, @expr.clone)
  end
end
