# command_helper.rb
#
# AUTHOR::  Kyle Mullins

module CommandHelper
  def create_handler(handler_class, event)
    handler_class.new(Omnic.bot, get_server(event), get_user(event))
  end

  def get_server(event)
    if event.respond_to?(:server) && !event.server.nil?
      event.server
    elsif event.respond_to?(:channel) && !event.channel.server.nil?
      event.channel.server
    end
  end

  def get_channel(event)
    event.respond_to?(:channel) ? event.channel : nil
  end

  def get_user(event)
    if event.respond_to?(:author) && !event.author.nil?
      event.author
    elsif event.respond_to?(:user) && !event.user.nil?
      event.user
    end
  end

  def pm?(message_event)
    !message_event.respond_to?(:server) || message_event.server.nil?
  end

  def feature_enabled?(feature, event)
    return true if feature.nil?

    server = get_server(event)
    return true if server.nil?

    feature.enabled?(Redis::Namespace.new(get_server_namespace(server),
                                          redis: Omnic.redis))
  end

  def get_server_namespace(server)
    "SERVER:#{server.id}"
  end

  def get_user_namespace(user)
    "USER:#{user.id}"
  end

  def format_obj(obj)
    return '' if obj.nil?

    "[#{obj.name}:#{obj.id}]"
  end
end
