# image_link_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class ImageLinkProcessor < SimplePatternProcessor
  def pattern
    %r{https?:\/\/\S+}
  end

  def filter(link)
    /(\.jpg|\.png|\.gif|imgur\.com|gfycat\.com)/ === link &&
      !link.include?('gallery')
  end

  def to_html(link)
    "<img src=\"#{to_image_url(link)}\">"
  end

  def to_image_url(link)
    if link.include?('imgur.com') && link !~ /\.[a-z]+$/
      link + '.gif'
    elsif link.include?('gfycat.com') && link !~ /\.[a-z]+$/
      "https://giant.gfycat.com/#{link.split('/')[-1]}.gif"
    else
      link
    end
  end
end
