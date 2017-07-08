# expression_builder.rb
#
# Author::  Kyle Mullins

require_relative 'binary_operator'
require_relative 'constant_value'
require_relative 'dice_term'
require_relative 'simple_expression'
require_relative 'parser_error'

class ExpressionBuilder
  def self.build(expression_str)
    tokens = tokenize(expression_str)
    validate(tokens)

    build_expression(to_postfix_form(tokens)).tap do |expression|
      expression.validate
    end
  end

  # Private Class methods

  OPERATOR_REGEX = /[-%+*\/]/

  def self.tokenize(expression_str)
    expression_str.split(/([-+*%\/()])/).reject{ |token| token == '' }
  end

  def self.validate(tokens)
    raise ParserError, 'Invalid expression' if tokens.empty?
    raise ParserError, 'Invalid expression' if OPERATOR_REGEX === tokens.first || OPERATOR_REGEX === tokens.last
    raise ParserError, 'Mismatched parenthesis' unless tokens.count('(') == tokens.count(')')
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
      when /[%*\/]/
        2
    end
  end

  def self.build_expression(postfix_tokens)
    expr_stack = []

    postfix_tokens.each do |token|
      case token
        when OPERATOR_REGEX
          right_expr = expr_stack.pop
          left_expr = expr_stack.pop
          operator = BinaryOperator.new(token)

          expr_stack.push(SimpleExpression.new(left_expr, operator, right_expr))
        when /\d*d\d+/i
          expr_stack.push(DiceTerm.new(token))
        else
          expr_stack.push(ConstantValue.new(token))
      end
    end

    expr_stack.pop
  end

  private_class_method :tokenize, :validate, :to_postfix_form, :precedence, :build_expression
end
