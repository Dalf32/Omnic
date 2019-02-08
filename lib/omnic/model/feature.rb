# feature.rb
#
# Author::  Kyle Mullins

class Feature
  FEATURE_ON = 'on'.freeze
  FEATURE_OFF = 'off'.freeze

  attr_reader :name, :default_enabled, :description

  def initialize(name, default_enabled, description)
    @name = name
    @default_enabled = default_enabled
    @description = description
    @commands = []
  end

  def add_command(command_name)
    return if command?(command_name)

    @commands << command_name
  end

  def has_command?(command_name)
    @commands.include?(command_name)
  end

  alias command? has_command?

  def enabled?(server_redis)
    return true if @default_enabled && !server_redis.exists(feature_key)

    server_redis.get(feature_key) == FEATURE_ON
  end

  def set_enabled(server_redis, is_enabled)
    server_redis.set(feature_key, is_enabled ? FEATURE_ON : FEATURE_OFF)
  end

  def to_s(redis = nil)
    str = "**#{@name}**"
    str += " (#{enabled?(redis) ? 'On' : 'Off'})" unless redis.nil?
    str += @description.empty? ? "\n" : ": #{@description}\n"
    str += "    #{@commands.join(', ')}"
    str
  end

  private

  def feature_key
    "admin:feature:#{@name}"
  end
end
