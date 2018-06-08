# dice_roll_handler.rb
#
# Author::  Kyle Mullins

require_relative 'dice_roll/expression_builder'

class DiceRollHandler < CommandHandler
  feature :dice, default_enabled: true

  command(:roll, :roll_dice)
    .feature(:dice).min_args(1).usage('roll <dice_expr>')
    .description('Parses and rolls the given dice expression, then shows the results.')

  command(:saveroll, :save_roll)
    .feature(:dice).min_args(2).usage('saveroll <roll_name> <dice_expr>')
    .description('Saves the given dice expression to the given name, which can then be used on its own or within another expression.')

  command(:delroll, :delete_roll)
    .feature(:dice).args_range(1, 1).usage('delroll <roll_name>')
    .description('Deletes the saved roll with the given name.')

  command(:listrolls, :list_saved_rolls)
    .feature(:dice).max_args(0).usage('listrolls')
    .description('Lists all of the rolls you have saved.')

  command(:rollhelp, :show_roll_help)
    .feature(:dice).max_args(0).usage('rollhelp')
    .description('Shows an explanation of some of the dice expression syntax.')

  def redis_name
    :dice_roll
  end

  def roll_dice(_event, *dice_expr)
    expression = build_expression(dice_expr.join)
    rolled_value = expression.eval

    "Rolling #{dice_expr.join(' ')}```#{expression.print_eval} = #{rolled_value}```"
  rescue ParserError => err
    err.message
  rescue ZeroDivisionError
    'Cannot divide by 0'
  end

  def save_roll(_event, roll_name, *dice_expr)
    roll_name.downcase!

    return "You already have a roll saved under the name #{roll_name}." if user_redis.sismember(ROLL_SET_KEY, roll_name)

    build_expression(dice_expr.join)

    user_redis.sadd(ROLL_SET_KEY, roll_name)
    user_redis.set(get_roll_key(roll_name), dice_expr.join)

    "Roll saved: #{roll_name} = #{dice_expr.join(' ')}"
  rescue ParserError => err
    err.message
  end

  def delete_roll(_event, roll_name)
    roll_name.downcase!

    return "No roll saved matching the name #{roll_name}" unless user_redis.sismember(ROLL_SET_KEY, roll_name)

    user_redis.del(get_roll_key(roll_name))
    user_redis.srem(ROLL_SET_KEY, roll_name)

    "Roll deleted: #{roll_name}"
  end

  def list_saved_rolls(_event)
    rolls = user_redis.smembers(ROLL_SET_KEY)

    return 'No saved rolls yet!' if rolls.empty?

    list_text = ''

    rolls.sort.each_slice(3) do |row|
      list_text += row.map { |roll| format('%-16s', roll) }.join(' ') + "\n"
    end

    "***Available rolls***\n```#{list_text}```"
  end

  def show_roll_help(_event)
    <<~HELP
      A basic expression contains the Number of Dice, followed by `d`, finally followed by the Dice Rank.
        *ex:* `4d6` *would roll 4 6-sided dice, and return the result.*

      Basic math can be performed with the results of the dice rolls, and multiple rolls can be used in the same expression.
      Supported operators:```
      Addition:       +
      Subtraction:    -
      Multiplication: *
      Division:       /
      Modulus:        %```
      A `!` at the end of a dice expression will 'explode' the results, meaning an extra die is rolled for each maximum result rolled.
      To 'keep' only the highest n results, put `k` or `kh` after the Dice Rank in a dice expression, followed by the number of results to keep.
      Likewise keeping only the lowest n results is done with `kl` and the number of results to keep.
        *ex:* `4d6k2! + 14` *would roll 4 6-sided dice, explode them, keep the highest 2 results, then add 14.*

      Saved rolls can be used simply by including the name the roll was saved under within the expression.
        *ex: If we have the roll* `2d20k1` *saved with the name 'adv', then rolling* `(adv + 14) * 2` *would expand the 'adv' roll and we would roll* `(2d20k1 + 14) * 2`
    HELP
  end

  private

  ROLL_SET_KEY = 'rolls'.freeze unless defined? ROLL_SET_KEY
  SAVED_ROLL_KEY = 'saved_roll'.freeze unless defined? SAVED_ROLL_KEY

  def build_expression(dice_expr)
    ExpressionBuilder.build(dice_expr, get_saved_rolls).tap do |expression|
      log.debug("Expression: #{expression}")
    end
  end

  def get_saved_rolls
    roll_names = user_redis.smembers(ROLL_SET_KEY)
    return {} if roll_names.empty?

    roll_values = user_redis.mget(roll_names.map { |roll_name| get_roll_key(roll_name) })
    Hash[roll_names.zip(roll_values)]
  end

  def get_roll_key(roll_name)
    SAVED_ROLL_KEY + ':' + roll_name
  end
end