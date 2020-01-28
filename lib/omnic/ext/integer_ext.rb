# IntegerExt
#
# AUTHOR::  Kyle Mullins

module IntegerExt
  def format_currency
    '$' + to_s.reverse.scan(/(\d*\.\d{1,3}|\d{1,3})/).join(',').reverse
  end
end
