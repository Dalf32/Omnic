# PoolBuilder
#
# AUTHOR::  Kyle Mullins

require_relative 'constant_value'
require_relative 'dice_pool'
require_relative 'dice_term'
require_relative 'parser_error'

class PoolBuilder
  def self.build(pool_str)
    tokens = tokenize(pool_str)
    validate(tokens)

    build_pool(tokens)
  end

  # Private Class methods

  OPERATOR_REGEX = %r{([-%+*\/()])}.freeze

  def self.tokenize(pool_str)
    pool_str.downcase.split(',').map { |token| token.split(OPERATOR_REGEX) }
            .flatten.map(&:strip).reject(&:empty?)
  end

  INVALID_POOL_ERR = 'Invalid pool'.freeze
  OPERATORS_DISALLOWED_ERR = 'Operators are not allowed in pools'.freeze
  ONLY_DICE_ALLOWED_ERR = 'Only dice terms are allowed in pools'.freeze

  def self.validate(tokens)
    raise ParserError, INVALID_POOL_ERR if tokens.empty?
    raise ParserError, OPERATORS_DISALLOWED_ERR if tokens.any?(OPERATOR_REGEX)

    unless tokens.all?(/\d*d(\d+|F)/i)
      raise ParserError, ONLY_DICE_ALLOWED_ERR
    end
  end

  def self.build_pool(tokens)
    DicePool.new.tap { |pool| tokens.each { |token| pool << DiceTerm.new(token, is_pool: true) } }
  end

  private_class_method :tokenize, :validate, :build_pool
end
