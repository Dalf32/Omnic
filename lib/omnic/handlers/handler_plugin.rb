# HandlerPlugin
#
# AUTHOR::  Kyle Mullins

class HandlerPlugin < CommandHandler
  PLUGIN_TARGET_ERROR = 'Plugin Target must be specified.'

  def self.command(command, command_method, **args)
    raise PLUGIN_TARGET_ERROR unless respond_to?(:plugin_target)

    plugin_target.class_eval(
      %(
      def #{command_method}(*args)
        #{self}.new(self).send(:#{command_method}, *args)
      end
      ))
    plugin_target.command(command, command_method, **args)
  end

  def self.event(event, event_method, **args)
    raise PLUGIN_TARGET_ERROR unless respond_to?(:plugin_target)

    plugin_target.class_eval(
      %(
      def #{event_method}(*args)
        #{self}.new(self).send(:#{event_method}, *args)
      end
      ))
    plugin_target.event(event, event_method, **args)
  end

  def self.feature(*args)
    raise PLUGIN_TARGET_ERROR unless respond_to?(:plugin_target)

    plugin_target.feature(*args)
  end

  def initialize(handler)
    super(handler.bot, handler.server, handler.user)

    @handler = handler
  end

  def config_name
    @handler.config_name
  end

  def redis_name
    @handler.redis_name
  end
end
