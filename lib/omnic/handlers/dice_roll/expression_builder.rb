# expression_builder.rb
#
# Author::  Kyle Mullins

require_relative 'binary_operator'
require_relative 'constant_value'
require_relative 'dice_term'
require_relative 'repeat_expression'
require_relative 'simple_expression'
require_relative 'parser_error'

class ExpressionBuilder
  def self.build(expression_str, saved_rolls)
    tokens = tokenize(expression_str, saved_rolls)
    validate(tokens)

    build_expression(to_postfix_form(tokens)).tap(&:validate)
  end

  # Private Class methods

  OPERATOR_REGEX = %r{[-%+*\/]}.freeze
  SAVED_ROLL_REGEX = /\A[a-z]+\z/i.freeze
  REPEAT_OPERATOR = 'Repeat'.freeze

  def self.tokenize(expression_str, saved_rolls)
    expression_str.downcase.partition(REPEAT_OPERATOR.downcase)
                  .map { |t| t.split(%r{([-+*%\/()])}) }.flatten
                  .reject { |token| token == '' }.map do |token|
      if token.capitalize == REPEAT_OPERATOR
        token.capitalize
      elsif SAVED_ROLL_REGEX === token && saved_rolls.key?(token.downcase)
        tokenize(saved_rolls[token.downcase], saved_rolls)
      else
        token
      end
    end.flatten
  end

  INVALID_EXPRESSION_ERR = 'Invalid expression'.freeze
  PAREN_MISMATCH_ERR = 'Mismatched parenthesis'.freeze
  REPEAT_MISPLACED_ERR = 'Repeat must be the last operator if it is present and be followed by one term or expression'.freeze
  MULTIPLE_REPEAT_ERR = 'Repeat may not appear more than once'.freeze
  NO_SAVED_ROLL_ERR = 'No saved roll matching '.freeze

  def self.validate(tokens)
    raise ParserError, INVALID_EXPRESSION_ERR if tokens.empty?
    raise ParserError, INVALID_EXPRESSION_ERR if OPERATOR_REGEX === tokens.first || OPERATOR_REGEX === tokens.last
    raise ParserError, PAREN_MISMATCH_ERR unless tokens.count('(') == tokens.count(')')
    raise ParserError, REPEAT_MISPLACED_ERR if tokens.include?(REPEAT_OPERATOR) && tokens[-2] != REPEAT_OPERATOR
    raise ParserError, MULTIPLE_REPEAT_ERR if tokens.count(REPEAT_OPERATOR) > 1

    tokens.each do |token|
      raise ParserError, NO_SAVED_ROLL_ERR + token if SAVED_ROLL_REGEX === token && token != REPEAT_OPERATOR
    end
  end

  def self.to_postfix_form(tokens)
    oper_stack = []
    postfix_form = []

    tokens.each do |token|
      case token
      when OPERATOR_REGEX
        if oper_stack.empty? || oper_stack.last == '('
          oper_stack.push(token)
        else
          until oper_stack.empty? || precedence(token) > precedence(oper_stack.last)
            postfix_form << oper_stack.pop
          end

          oper_stack.push(token)
        end
      when '('
        oper_stack.push(token)
      when ')'
        until oper_stack.last == '('
          postfix_form << oper_stack.pop
        end

        oper_stack.pop
      when REPEAT_OPERATOR
        oper_stack.push(token)
      else
        postfix_form << token
      end
    end

    postfix_form + oper_stack.reverse
  end

  def self.precedence(operator)
    case operator
    when /[-+]/
      1
    when %r{[%*\/]}
      2
    else
      0
    end
  end

  def self.build_expression(postfix_tokens)
    expr_stack = []
    repeat_expr = nil

    postfix_tokens.each do |token|
      case token
      when OPERATOR_REGEX
        right_expr = expr_stack.pop
        left_expr = expr_stack.pop
        operator = BinaryOperator.new(token)

        expr_stack.push(SimpleExpression.new(left_expr, operator, right_expr))
      when /\d*d\d+/i
        expr_stack.push(DiceTerm.new(token))
      when REPEAT_OPERATOR
        repeat_count_expr = expr_stack.pop
        repeat_expr = RepeatExpression.new(repeat_count_expr)
      else
        expr_stack.push(ConstantValue.new(token))
      end
    end

    if repeat_expr.nil?
      expr_stack.pop
    else
      repeat_expr.set_expression(expr_stack.pop)
      repeat_expr
    end
  end

  private_class_method :tokenize, :validate, :to_postfix_form, :precedence, :build_expression
end
