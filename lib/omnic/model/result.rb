# result.rb
#
# AUTHOR::  Kyle Mullins

class Result
  attr_accessor :value, :error

  def initialize(value: nil, error: nil)
    @value = value
    @error = error
  end

  def success?
    error.nil?
  end

  def failure?
    !success?
  end
end
