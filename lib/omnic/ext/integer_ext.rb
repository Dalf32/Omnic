# IntegerExt
#
# AUTHOR::  Kyle Mullins

module IntegerExt
  def format_currency(simplify_large: true)
    return format_large_currency if self >= 1_000_000 && simplify_large

    neg = negative? ? '-' : ''
    "#{neg}$" + to_s.reverse.scan(/(\d{1,3})/).join(',').reverse
  end

  private

  def format_large_currency
    if self >= 1_000_000_000_000_000_000
      exp = self.digits.count - 1
      suffix = "e#{exp}"
      val = self / 10.0**exp
    elsif self >= 1_000_000_000_000_000
      suffix = ' Quadrillion'
      val = self / 1_000_000_000_000_000.0
    elsif self >= 1_000_000_000_000
      suffix = ' Trillion'
      val = self / 1_000_000_000_000.0
    elsif self >= 1_000_000_000
      suffix = ' Billion'
      val = self / 1_000_000_000.0
    else
      suffix = ' Million'
      val = self / 1_000_000.0
    end

    "#{val.format_currency}#{suffix}"
  end
end
