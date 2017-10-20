# bare_link_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class BareLinkProcessor < SimplePatternProcessor
  def pattern
    %r{https?:\/\/\S+}
  end

  def to_html(link)
    "<a href=\"#{link}\">#{link}</a>"
  end
end
