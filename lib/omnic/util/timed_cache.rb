# command.rb
#
# AUTHOR::  Kyle Mullins

class TimedCache
  def initialize(default_expiration_s)
    @default_expiration_s = default_expiration_s
    @backing_hash = {}
  end

  def []=(key, value)
    put(key, value)
  end

  def put(key, value, expire_s = @default_expiration_s)
    @backing_hash[key] = [value, Time.now.to_i + expire_s]
    value
  end

  def get(key)
    return nil unless @backing_hash.key?(key)

    if key_expired?(key)
      delete(key)
      return nil
    end

    @backing_hash[key].first
  end
  alias [] get

  def key?(key)
    return false unless @backing_hash.key?(key)

    if key_expired?(key)
      delete(key)
      return false
    end

    true
  end
  alias has_key? key?
  alias include? key?
  alias member? key?

  def cleanup
    @backing_hash = @backing_hash.delete_if { |_, expiry| expired?(expiry) }
  end

  private

  DELEGATE_METHODS = [:any?, :clear, :delete, :empty?, :keys, :length, :rehash, :size]

  def method_missing(symbol, *args)
    return @backing_hash.send(symbol, *args) if DELEGATE_METHODS.include?(symbol)

    super
  end

  def respond_to_missing?(symbol, include_private = false)
    return true if DELEGATE_METHODS.include?(symbol)

    super
  end

  def key_expired?(key)
    expired?(@backing_hash[key].last || 0)
  end

  def expired?(expiry_s)
    Time.now.to_i > expiry_s
  end
end
