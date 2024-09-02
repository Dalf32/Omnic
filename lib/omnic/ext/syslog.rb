# syslog.rb
#
# Author::  Kyle Mullins

require 'syslog_protocol'
require 'socket'

module Logging::Appenders
  def self.syslog(**args)
    return Logging::Appenders::Syslog if args.empty?

    Logging::Appenders::Syslog.new(**args)
  end

  class Syslog < Logging::Appender
    def initialize(hostname:, port:, local_hostname:, tag:, **opts)
      super("#{hostname}:#{port}", opts)

      @local_hostname = local_hostname || Socket.gethostname
      @tag = tag
      @socket = UDPSocket.new.tap do |socket|
        socket.connect(hostname, port)
      end
    end

    def write(event)
      message = event.instance_of?(Logging::LogEvent) ? @layout.format(event) : event.to_s
      packet = create_packet(message)
      send_packet(packet)
    end

    def close(footer = true)
      super

      @socket.close
      self
    end

    private

    def send_packet(packet)
      @socket.send(packet.assemble, 0)
    end

    def create_packet(message)
      SyslogProtocol::Packet.new.tap do |packet|
        packet.facility = 'user'
        packet.severity = 'notice'
        packet.hostname = @local_hostname
        packet.tag = @tag
        packet.content = message
      end
    end
  end
end
