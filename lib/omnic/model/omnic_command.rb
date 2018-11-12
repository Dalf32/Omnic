# command.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'command_helper'

class OmnicCommand
  include CommandHelper

  attr_reader :handler_class, :name

  def initialize(handler_class, name, method_name)
    @handler_class = handler_class
    @name = name
    @method_name = method_name
    @pm_enabled = true
    @other_params = {}
    @error = nil
    @owner_only = false
  end

  def id
    "#{@handler_class} #{@name}"
  end

  def feature(feature)
    @feature = feature

    if Omnic.features.key?(@feature)
      Omnic.features[@feature].add_command(@name)
    else
      @error = "Invalid Feature: #{@feature}"
    end

    self
  end

  def pm_enabled(enabled)
    @pm_enabled = enabled
    self
  end

  def min_args(num)
    @other_params[:min_args] = num
    self
  end

  def max_args(num)
    @other_params[:max_args] = num
    self
  end

  def args_range(min, max)
    min_args(min).max_args(max)
  end

  def usage(usage)
    @other_params[:usage] = usage
    self
  end

  def description(desc)
    @other_params[:description] = desc
    self
  end

  def permissions(*perms)
    @other_params[:required_permissions] = perms
    self
  end

  def owner_only(owner_only)
    @owner_only = owner_only
    self
  end

  def limit(limit: nil, span: nil, delay: nil, action: nil)
    limit_args = { limit: limit, time_span: span, delay: delay }
                 .reject { |_key, value| value.nil? }

    Omnic.rate_limiter.bucket(@name, **limit_args)

    @limit_action = action
    self
  end

  def other_params(**args)
    @other_params.merge!(args)
    self
  end

  def register
    raise @error if error?

    Omnic.bot.command @name, **@other_params do |trig_event, *other_args|
      Omnic.logger.info("Command triggered: #{id} #{other_args.join(' ')}")
      Omnic.logger.debug("  Context: Server #{format_obj(trig_event.server)}; Channel #{format_obj(trig_event.channel)}; Author #{format_obj(trig_event.author)}; PM? #{pm?(trig_event)}")

      if @owner_only && !owner?(trig_event.author)
        Omnic.logger.debug('  Command not run because user is not the Bot Owner')
        next
      end

      if pm?(trig_event) && !@pm_enabled
        Omnic.logger.debug('  Command not run because it is not allowed in PMs')
        trig_event.message.reply("Command #{@name} cannot be used in DMs.")
        next
      end

      unless feature_enabled?(Omnic.features[@feature], trig_event)
        Omnic.logger.debug('  Command not run because the feature is not enabled on this server')
        next
      end

      unless command_allowed?(@name, trig_event)
        Omnic.logger.debug('  Command not run because it is not allowed in this channel')
        trig_event.message.reply("Command #{@name} is not allowed in this channel.")
        next
      end

      handler = create_handler(@handler_class, trig_event)
      limit_scope = get_server(trig_event) || get_user(trig_event)
      time_remaining = Omnic.rate_limiter.rate_limited?(@name, limit_scope)

      if time_remaining # This will be false when not rate limited
        Omnic.logger.debug('  Command was rate limited')
        handler.send(@limit_action, trig_event, time_remaining) unless @limit_action.nil?
      else
        handler.send(@method_name, trig_event, *other_args)
      end
    end
  end

  private

  def error?
    !@error.nil?
  end

  def command_allowed?(command, triggering_event)
    server = get_server(triggering_event)
    return true if server.nil?

    key_template = "#{get_server_namespace(server)}:admin:%{type}:#{command}"
    channel_whitelist_key = format(key_template, type: 'channel_whitelist')
    channel_blacklist_key = format(key_template, type: 'channel_blacklist')
    channel = get_channel(triggering_event)

    unless channel.nil?
      if Omnic.redis.exists(channel_whitelist_key) &&
         !Omnic.redis.sismember(channel_whitelist_key, channel.id.to_s)
        return false
      elsif Omnic.redis.exists(channel_blacklist_key) &&
            Omnic.redis.sismember(channel_blacklist_key, channel.id.to_s)
        return false
      end
    end

    true
  end
end
