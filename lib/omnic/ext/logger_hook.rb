# logger_hook.rb
#
# Author::  Kyle Mullins

module LoggerHook
  attr_accessor :backing_logger
  
  def simple_write(_stream, message, mode, _thread_name, _timestamp)
    if @backing_logger.nil?
      return super
    end

    case mode[:long]
      when 'DEBUG'
        @backing_logger.debug(message)
      when 'INFO', 'GOOD'
        @backing_logger.info(message)
      when 'WARN'
        @backing_logger.warn(message)
      when 'ERROR'
        @backing_logger.error(message)
    end
  end
end
