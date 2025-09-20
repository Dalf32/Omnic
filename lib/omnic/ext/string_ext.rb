# frozen_string_literal: true

module StringExt
  def to_bool
    if casecmp?('true')
      true
    elsif casecmp?('false')
      false
    else
      nil
    end
  end
end
