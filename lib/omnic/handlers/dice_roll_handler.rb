# dice_roll_handler.rb
#
# Author::  Kyle Mullins

require_relative 'dice_roll/expression_builder'
require_relative 'dice_roll/pool_builder'

class DiceRollHandler < CommandHandler
  feature :dice, default_enabled: true,
                 description: 'Provides a robust dice roller with the ability to save/recall rolls.'

  command(:roll, :roll_dice)
    .feature(:dice).min_args(1).usage('roll <dice_expr>')
    .description('Parses and rolls the given dice expression, then shows the results.')

  command(:saveroll, :save_roll)
    .feature(:dice).min_args(2).usage('saveroll <roll_name> <dice_expr>')
    .description('Saves the given dice expression to the given name, which can then be used on its own or within another expression.')

  command(:savesharedroll, :save_shared_roll)
    .feature(:dice).min_args(2).usage('savesharedroll <roll_name> <dice_expr>')
    .pm_enabled(false).permissions(:manage_channels)
    .description('Saves the given dice expression to the given name, which can then be used on its own or within another expression.')

  command(:delroll, :delete_roll)
    .feature(:dice).args_range(1, 1).usage('delroll <roll_name>')
    .description('Deletes the saved roll with the given name.')

  command(:delsharedroll, :delete_shared_roll)
    .feature(:dice).args_range(1, 1).usage('delsharedroll <roll_name>')
    .pm_enabled(false).permissions(:manage_channels)
    .description('Deletes the saved shared roll with the given name.')

  command(:listrolls, :list_saved_rolls)
    .feature(:dice).no_args.usage('listrolls')
    .description('Lists all of the rolls you have saved.')

  command(:rollhelp, :show_roll_help)
    .feature(:dice).no_args.usage('rollhelp')
    .description('Shows an explanation of some of the dice expression syntax.')

  command(:tokenroll, :tokenize_roll)
    .feature(:dice).owner_only(true).min_args(1).usage('tokenroll <dice_expr>')
    .description('Tokenizes but does not fully build the given dice expression, showing just the tokens.')

  command(:buildroll, :build_roll)
    .feature(:dice).owner_only(true).min_args(1).usage('buildroll <dice_expr>')
    .description('Parses but does not roll the given dice expression, showing the built expression.')

  command(:rollpool, :roll_pool)
    .feature(:dice).min_args(1).usage('rollpool <dice_pool>')
    .description('Rolls a pool of dice and just displays the results without doing any math operations.')

  command(:reroll, :reroll)
    .feature(:dice).no_args.usage('reroll')
    .description('Rerolls the last thing you rolled.')

  def redis_name
    :dice_roll
  end

  def roll_dice(_event, *dice_expr)
    save_last_roll(:roll_dice, dice_expr.join(' '))
    expression = build_expression(dice_expr.join)

    "Rolling #{dice_expr.join(' ')}\n```#{expression.eval_and_print}```"
  rescue ParserError => err
    err.message
  rescue ZeroDivisionError
    'Cannot divide by 0'
  end

  def save_roll(_event, roll_name, *dice_expr)
    save_dice_roll(roll_name, dice_expr, user_redis)
  end

  def save_shared_roll(_event, roll_name, *dice_expr)
    save_dice_roll(roll_name, dice_expr, server_redis)
  end

  def delete_roll(_event, roll_name)
    delete_dice_roll(roll_name, user_redis)
  end

  def delete_shared_roll(_event, roll_name)
    delete_dice_roll(roll_name, server_redis)
  end

  def list_saved_rolls(_event)
    user_rolls = saved_rolls(user_redis)
    server_rolls = saved_rolls(server_redis)

    return 'No saved rolls yet!' if user_rolls.empty? && server_rolls.empty?

    list_text = '***Available rolls***'
    list_text += "\n*Your rolls*\n```#{format_saved_rolls(user_rolls)}```" unless user_rolls.empty?
    list_text += "\n*Shared rolls*\n```#{format_saved_rolls(server_rolls)}```" unless server_rolls.empty?
    list_text
  end

  def show_roll_help(_event)
    <<~HELP
      A basic expression contains the Number of Dice, followed by `d`, finally followed by the Dice Rank. The Rank may be a integer number or 'F' for FATE dice.
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

      Saved rolls can be used simply by including the name the roll was saved under within the expression. Your saved rolls take precedence over shared ones.
        *ex: If we have the roll* `2d20k1` *saved with the name 'adv', then rolling* `(adv + 14) * 2` *would expand the 'adv' roll and we would roll* `(2d20k1 + 14) * 2`

      An expression can be repeated a number of times by appending the keyword `Repeat` followed by a basic expression or number.
        *ex:* `1d20 + 2 Repeat 3` *would roll* `1d20 + 2` *3 times.*

      Functions may be invoked by entering the function name followed by an expression enclosed in parenthesis.
        *ex:* `Max(2d6 + 4)` *would call the* `Max` *function on the expression* `2d6 + 4`
      Supported functions:```
      Min: Calculates the minimum possible result (ignores exploding dice)
      Max: Calculates the maximum possible result (ignores exploding dice)
      Avg: Calculates the average result (ignores exploding dice)```
    HELP
  end

  def tokenize_roll(_event, *dice_expr)
    expression = tokenize_expression(dice_expr.join)

    "Tokenized #{dice_expr.join(' ')} as\n```#{expression}```"
  end

  def build_roll(_event, *dice_expr)
    expression = build_expression(dice_expr.join)

    "Parsed #{dice_expr.join(' ')} as\n```#{expression}```"
  rescue ParserError => err
    err.message
  end

  def roll_pool(_event, *dice_pool)
    save_last_roll(:roll_pool, dice_pool.join(' '))
    pool = PoolBuilder.build(dice_pool.join(','))

    "Rolling pool #{dice_pool.join(' ')}\n```#{pool.eval_and_print}```"
  rescue ParserError => err
    err.message
  end

  def reroll(event)
    last_roll = get_last_roll
    return 'No recent roll.' if last_roll.nil?

    last_roll = last_roll.split(' ')
    send(last_roll.first, event, last_roll[1..-1])
  end

  private

  ROLL_SET_KEY = 'rolls'.freeze unless defined? ROLL_SET_KEY
  SAVED_ROLL_KEY = 'saved_roll'.freeze unless defined? SAVED_ROLL_KEY
  LAST_ROLL_KEY = 'last_roll'.freeze unless defined? LAST_ROLL_KEY

  def tokenize_expression(dice_expr)
    saved_die_rolls = saved_rolls(server_redis).merge(saved_rolls(user_redis))
    ExpressionBuilder.tokenize(dice_expr, saved_die_rolls)
  end

  def build_expression(dice_expr)
    saved_die_rolls = saved_rolls(server_redis).merge(saved_rolls(user_redis))
    ExpressionBuilder.build(dice_expr, saved_die_rolls).tap do |expression|
      log.debug("Expression: #{expression}")
    end
  end

  def saved_rolls(redis)
    return {} if redis.nil?

    roll_names = redis.smembers(ROLL_SET_KEY)
    return {} if roll_names.empty?

    roll_values = redis.mget(roll_names.map { |roll_name| get_roll_key(roll_name) })
    Hash[roll_names.zip(roll_values)]
  end

  def get_roll_key(roll_name)
    SAVED_ROLL_KEY + ':' + roll_name
  end

  def save_dice_roll(roll_name, dice_expr, redis)
    roll_name.downcase!

    return "You already have a roll saved under the name #{roll_name}." if redis.sismember(ROLL_SET_KEY, roll_name)

    build_expression(dice_expr.join)

    redis.sadd(ROLL_SET_KEY, roll_name)
    redis.set(get_roll_key(roll_name), dice_expr.join)

    "Roll saved: #{roll_name} = #{dice_expr.join(' ')}"
  rescue ParserError => err
    err.message
  end

  def delete_dice_roll(roll_name, redis)
    roll_name.downcase!

    return "No roll saved matching the name #{roll_name}" unless redis.sismember(ROLL_SET_KEY, roll_name)

    redis.del(get_roll_key(roll_name))
    redis.srem(ROLL_SET_KEY, roll_name)

    "Roll deleted: #{roll_name}"
  end

  def format_saved_rolls(rolls)
    longest_name = rolls.keys.map(&:length).max
    name_fmt = "%-#{longest_name}s"

    rolls.map do |name, expr|
      expression = build_expression(expr)
      "#{format(name_fmt, name)} = #{expression.print}"
    end.join("\n")
  end

  def save_last_roll(method, roll_text)
    user_redis.setex(LAST_ROLL_KEY, 60 * 60, "#{method} #{roll_text}")
  end

  def get_last_roll
    user_redis.get(LAST_ROLL_KEY)
  end
end
