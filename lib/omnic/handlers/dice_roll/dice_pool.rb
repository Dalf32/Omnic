# DicePool
#
# AUTHOR::  Kyle Mullins

class DicePool
  def initialize(pool = [])
    @pool = pool
  end

  def add(dice_term)
    @pool << dice_term
  end
  alias_method :<<, :add

  def eval
    @pool.each(&:eval)
  end

  def eval_and_print
    eval
    "#{print_eval}"
  end

  def print
    "#{@pool.map(&:print).join(', ')}"
  end

  def print_eval
    "#{@pool.map(&:print_eval).join(' ')}"
  end

  def to_s
    "DicePool(#{@pool.join(', ')})"
  end

  def clone
    DicePool.new(@pool.map(&:clone))
  end
end
