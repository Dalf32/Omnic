# dice_term.rb
#
# Author::  Kyle Mullins

require_relative 'parser_error'

class DiceTerm
  def initialize(expression)
    @num_dice, @dice_rank = *expression.downcase.split('d')
  end

  def validate
    begin
      Integer(@num_dice)
    rescue ArgumentError
      raise ParserError, "#{@num_dice} is not a valid Integer"
    end

    begin
      Integer(@dice_rank)
    rescue ArgumentError
      raise ParserError, "#{@dice_rank} is not a valid Integer"
    end

    raise ParserError, 'Number of Dice cannot be 0' if !@num_dice.empty? && @num_dice.to_i == 0
    raise ParserError, 'Dice Rank cannot be 0' if @dice_rank.to_i == 0
  end

  def eval
    @rolls ||= (1..[1, @num_dice.to_i].max).map{ rand(1..@dice_rank.to_i) }
    @rolls.reduce(:+)
  end

  def print
    "#{@num_dice.to_i}d#{@dice_rank.to_i}"
  end

  def print_eval
    print + "[#{@rolls.join(' + ')}]"
  end

  def to_s
    "DiceTerm(#{@num_dice}d#{@dice_rank})"
  end
end
