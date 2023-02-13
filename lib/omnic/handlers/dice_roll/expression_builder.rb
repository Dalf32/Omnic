# expression_builder.rb
#
# Author::  Kyle Mullins

require_relative 'binary_operator'
require_relative 'constant_value'
require_relative 'dice_function'
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
  MIN_FUNCTION = 'Min'.freeze
  MAX_FUNCTION = 'Max'.freeze
  AVG_FUNCTION = 'Avg'.freeze
  FUNCTIONS_LIST = [MIN_FUNCTION, MAX_FUNCTION, AVG_FUNCTION]
  KEYWORDS_LIST = [REPEAT_OPERATOR] + FUNCTIONS_LIST
  KEYWORDS_REGEX = /#{KEYWORDS_LIST.join('|')}/i.freeze

  def self.tokenize(expression_str, saved_rolls)
    partition_all(expression_str.downcase, KEYWORDS_REGEX)
                  .map { |token| token.split(%r{([-+*%\/()])}) }.flatten
                  .reject { |token| token == '' }.map do |token|
      if KEYWORDS_LIST.include?(token.capitalize)
        token.capitalize
      elsif SAVED_ROLL_REGEX === token && saved_rolls.key?(token.downcase)
        tokenize(saved_rolls[token.downcase], saved_rolls)
      else
        token
      end
    end.flatten
  end

  def self.partition_all(str, sep)
    return [] if str.nil? || str.empty?

    parts = str.partition(sep)
    parts[0..1] + partition_all(parts.last, sep)
  end

  INVALID_EXPRESSION_ERR = 'Invalid expression'.freeze
  PAREN_MISMATCH_ERR = 'Mismatched parenthesis'.freeze
  REPEAT_MISPLACED_ERR = 'Repeat must be the last operator if it is present and be followed by one term or expression'.freeze
  MULTIPLE_REPEAT_ERR = 'Repeat may not appear more than once'.freeze
  NO_SAVED_ROLL_ERR = 'No saved roll matching '.freeze
  FUNCTION_MISPLACED_ERR = 'Functions must be followed by an expression in parenthesis'.freeze

  def self.validate(tokens)
    raise ParserError, INVALID_EXPRESSION_ERR if tokens.empty?
    raise ParserError, INVALID_EXPRESSION_ERR if OPERATOR_REGEX === tokens.first || OPERATOR_REGEX === tokens.last
    raise ParserError, PAREN_MISMATCH_ERR unless tokens.count('(') == tokens.count(')')
    raise ParserError, REPEAT_MISPLACED_ERR if tokens.include?(REPEAT_OPERATOR) && tokens[-2] != REPEAT_OPERATOR
    raise ParserError, MULTIPLE_REPEAT_ERR if tokens.count(REPEAT_OPERATOR) > 1
    raise ParserError, FUNCTION_MISPLACED_ERR if FUNCTIONS_LIST.include?(tokens.last)

    paren_stack = []

    tokens.each.with_index do |token, i|
      if FUNCTIONS_LIST.include?(token) && tokens[i + 1] != '('
        raise ParserError, FUNCTION_MISPLACED_ERR
      elsif SAVED_ROLL_REGEX === token && !KEYWORDS_LIST.include?(token)
        raise ParserError, NO_SAVED_ROLL_ERR + token
      elsif token == '('
        paren_stack << token
      elsif token == ')'
        raise ParserError, PAREN_MISMATCH_ERR if paren_stack.empty?
        paren_stack.pop
      end
    end

    raise ParserError, PAREN_MISMATCH_ERR unless paren_stack.empty?
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
      when '(', REPEAT_OPERATOR, *FUNCTIONS_LIST
        oper_stack.push(token)
      when ')'
        until oper_stack.last == '('
          postfix_form << oper_stack.pop
        end

        oper_stack.pop

        postfix_form << oper_stack.pop if FUNCTIONS_LIST.include?(oper_stack.last)
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
        repeat_expr = RepeatExpression.new(expr_stack.pop)
      when *FUNCTIONS_LIST
        expr_stack.push(DiceFunction.new(token, expr_stack.pop))
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

  private_class_method :partition_all, :validate, :to_postfix_form, :precedence, :build_expression
end
