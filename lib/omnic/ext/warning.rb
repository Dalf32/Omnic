# Warning
#
# AUTHOR::  Kyle Mullins

module Warning
  def warn(msg)
    Omnic.logger.warn(msg)
  end
end
