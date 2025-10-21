# frozen_string_literal: true

module FloatExt
  def format_currency
    neg = negative? ? '-' : ''
    rounded_val = round(2).to_s
    rounded_val = rounded_val.end_with?('.0') ? rounded_val[0..-3] : rounded_val
    "#{neg}$" + rounded_val.reverse.scan(/(\d*\.\d{1,3}|\d{1,3})/).join(',').reverse
  end
end
