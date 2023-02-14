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
    @is_fate_dice = @dice_rank.upcase == 'F'
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
      @is_fate_dice || Integer(@dice_rank)
    rescue ArgumentError
      raise ParserError, "#{@dice_rank} is not a valid Integer or 'F'"
    end

    raise ParserError, 'Number of Dice cannot be 0' if @num_dice.to_i.zero?
    raise ParserError, 'Dice Rank cannot be 0' if @dice_rank.to_i.zero? && !@is_fate_dice

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

  def min
    if @all_rolls.empty?
      @all_rolls = (1..[1, @num_dice.to_i].max).map { 1 }
      @kept_rolls = @all_rolls
      @kept_rolls = keep_high_dice(@all_rolls) if @keep_high
      @kept_rolls = keep_low_dice(@all_rolls) if @keep_low
    end

    @kept_rolls.reduce(:+)
  end

  def max
    if @all_rolls.empty?
      @all_rolls = (1..[1, @num_dice.to_i].max).map { @dice_rank.to_i }
      @kept_rolls = @all_rolls
      @kept_rolls = keep_high_dice(@all_rolls) if @keep_high
      @kept_rolls = keep_low_dice(@all_rolls) if @keep_low
    end

    @kept_rolls.reduce(:+)
  end

  def avg
    if @all_rolls.empty?
      @all_rolls = (1..[1, @num_dice.to_i].max).map { (1 + @dice_rank.to_i) / 2.0 }
      @kept_rolls = @all_rolls
      @kept_rolls = keep_high_dice(@all_rolls) if @keep_high
      @kept_rolls = keep_low_dice(@all_rolls) if @keep_low
    end

    @kept_rolls.reduce(:+).truncate
  end

  def eval_and_print
    rolled_value = eval
    "#{print_eval} = #{rolled_value}"
  end

  def print
    rank = @is_fate_dice ? 'F' : @dice_rank.to_i
    "#{@num_dice.to_i}d#{rank}#{keep_str(@keep_count.to_i)}#{explode_str}"
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
    return roll_fate_die if @is_fate_dice

    rand(1..@dice_rank.to_i)
  end

  def roll_fate_die
    [-1, 0, 1].sample
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
    separator = @is_fate_dice ? ' ' : ' + '

    @all_rolls.map do |roll|
      output = @is_fate_dice ? { -1 => '-', 0 => '0', 1 => '+' }[roll] : roll

      if (@keep_high || @keep_low) && unprinted_kept_rolls.include?(roll)
        unprinted_kept_rolls.delete_at(unprinted_kept_rolls.index(roll))
        output = "*#{output}*"
      end

      output = "#{output}!" if @is_exploding && exploded?(roll)

      output
    end.join(separator)
  end

  def exploded?(roll)
    roll == @is_fate_dice ? 1 : @dice_rank.to_i
  end
end
