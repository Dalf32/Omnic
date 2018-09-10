# omnic_event.rb
#
# AUTHOR::  Kyle Mullins

require_relative 'command_helper'

class OmnicEvent
  include CommandHelper

  attr_reader :handler_class, :event

  def initialize(handler_class, event, method_name)
    @handler_class = handler_class
    @event = event
    @method_name = method_name
    @pm_enabled = true
    @other_params = {}
    @error = nil
  end

  def id
    "#{@handler_class} #{@event}"
  end

  def feature(feature)
    @feature = feature
    @error = "Invalid Feature: #{@feature}" unless Omnic.features.key?(@feature)

    self
  end

  def pm_enabled(enabled)
    @pm_enabled = enabled
    self
  end

  def other_params(**args)
    @other_params.merge!(args)
    self
  end

  def register
    raise @error if error?

    Omnic.bot.public_send(@event, **@other_params) do |trig_event, *other_args|
      Omnic.logger.debug("Event triggered: #{id} #{other_args.join(' ')}")
      Omnic.logger.debug("  Context: Server #{format_obj(get_server(trig_event))}; Channel #{format_obj(get_channel(trig_event))}; Author #{format_obj(get_user(trig_event))}; PM? #{pm?(trig_event)}")

      if pm?(trig_event) && !@pm_enabled
        Omnic.logger.debug('  Event not fired because it is not enabled in PMs')
        next
      end

      unless feature_enabled?(Omnic.features[@feature], trig_event)
        Omnic.logger.debug('  Event not fired because the feature is not enabled on this server')
        next
      end

      handler = create_handler(@handler_class, trig_event)
      handler.send(@method_name, trig_event, *other_args)
    end
  end

  private

  def error?
    !@error.nil?
  end
end
