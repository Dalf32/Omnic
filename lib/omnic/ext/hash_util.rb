# hash_util.rb
#
# Author::	Kyle Mullins

module HashUtil
  def symbolize_keys(hash)
    return symbolize_keys_ary(hash) unless hash.is_a?(Hash)

    hash.inject({}){ |h, (k, v)| h[k.to_sym] = symbolize_keys(v); h }
  end

  def symbolize_keys_ary(array)
    return array unless array.is_a?(Array)

    array.map{ |e| symbolize_keys(e) }
  end
end