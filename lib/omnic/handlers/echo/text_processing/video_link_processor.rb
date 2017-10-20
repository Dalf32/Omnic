# video_link_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class VideoLinkProcessor < SimplePatternProcessor
  def pattern
    %r{https?:\/\/\S+}
  end

  def filter(link)
    /(\.webm|\.ogg|\.mp4|\.gifv)/ === link
  end

  def to_html(link)
    "<video #{attributes(link)}><source src=\"#{video_url(link)}\" type=\"#{video_type(link)}\"></video>"
  end

  def video_url(link)
    link.gsub('.gifv', '.webm')
  end

  def video_type(link)
    case link
    when /\.mp4/
      'video/mp4'
    when /(\.webm|\.gifv)/
      'video/webm'
    when /\.ogg/
      'video/ogg'
    else
      'video/mp4'
    end
  end

  def attributes(link)
    attribs = 'controls'

    if link.include?('gfycat') || link.include?('imgur')
      attribs += ' autoplay="autoplay" loop="loop" muted="muted" preload="auto"'
    end

    attribs
  end
end
