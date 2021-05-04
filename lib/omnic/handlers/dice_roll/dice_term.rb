# dice_term.rb
#
# Author::  Kyle Mullins

require_relative 'parser_error'

class DiceTerm
  def initialize(expression)
    expression.downcase!

    @is_exploding = false

    if expression.end_with?('!')
      expression.chop!
      @is_exploding = true
    end

    @keep_high = false
    @keep_low = false
    @keep_count = 0

    if expression.include?('k')
      expression, keep_str = *expression.split('k')

      if keep_str.start_with?('h')
        @keep_high = true
        @keep_count = keep_str[1..-1]
      elsif keep_str.start_with?('l')
        @keep_low = true
        @keep_count = keep_str[1..-1]
      else
        @keep_high = true
        @keep_count = keep_str
      end
    end

    @num_dice, @dice_rank = *expression.split('d')
    @num_dice = '1' if @num_dice.empty?
    @kept_rolls = []
    @all_rolls = []
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

    raise ParserError, 'Number of Dice cannot be 0' if @num_dice.to_i.zero?
    raise ParserError, 'Dice Rank cannot be 0' if @dice_rank.to_i.zero?

    begin
      Integer(@keep_count)
    rescue ArgumentError
      raise ParserError, "#{@keep_count} is not a valid Integer"
    end

    raise ParserError, 'Keep Count cannot be 0' if (@keep_high || @keep_low) && @keep_count.to_i.zero?
  end

  def eval
    if @all_rolls.empty?
      @all_rolls = (1..[1, @num_dice.to_i].max).map { roll_die }
      @all_rolls = explode_dice(@all_rolls) if @is_exploding
      @kept_rolls = @all_rolls
      @kept_rolls = keep_high_dice(@all_rolls) if @keep_high
      @kept_rolls = keep_low_dice(@all_rolls) if @keep_low
    end

    @kept_rolls.reduce(:+)
  end

  def print
    "#{@num_dice.to_i}d#{@dice_rank.to_i}#{keep_str(@keep_count.to_i)}#{explode_str}"
  end

  def print_eval
    print + "[#{format_die_rolls}]"
  end

  def to_s
    "DiceTerm(#{@num_dice}d#{@dice_rank}#{keep_str(@keep_count)}#{explode_str})"
  end

  private

  def explode_dice(dice_rolls)
    return [] if dice_rolls.empty?

    num_explodes = dice_rolls.count(@dice_rank.to_i)
    exploded_rolls = (1..num_explodes).map { roll_die }
    dice_rolls + explode_dice(exploded_rolls)
  end

  def keep_high_dice(dice_rolls)
    dice_rolls.max(@keep_count.to_i)
  end

  def keep_low_dice(dice_rolls)
    dice_rolls.min(@keep_count.to_i)
  end

  def roll_die
    rand(1..@dice_rank.to_i)
  end

  def keep_str(count)
    if @keep_high
      "kh#{count}"
    elsif @keep_low
      "kl#{count}"
    else
      ''
    end
  end

  def explode_str
    @is_exploding ? '!' : ''
  end

  def format_die_rolls
    unprinted_kept_rolls = @kept_rolls.dup

    @all_rolls.map do |roll|
      output = roll

      if (@keep_high || @keep_low) && unprinted_kept_rolls.include?(roll)
        unprinted_kept_rolls.delete_at(unprinted_kept_rolls.index(roll))
        output = "*#{output}*"
      end

      output += '!' if @is_exploding && roll == @dice_rank.to_i

      output
    end.join(' + ')
  end
end
