# youtube_link_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class YoutubeLinkProcessor < SimplePatternProcessor
  def pattern
    %r{https?:\/\/\S+}
  end

  def filter(link)
    /(youtu\.be|youtube\.com)/ === link
  end

  def to_html(link)
    "<iframe src=\"#{to_youtube_url(link)}\" frameborder=\"0\" allowfullscreen></iframe>"
  end

  def to_youtube_url(link)
    video_id = youtube_video_id(link)
    start_time = youtube_start_time(link)
    args = start_time.zero? ? '' : "?start=#{start_time}"
    "https://www.youtube.com/embed/#{video_id}#{args}"
  end

  def youtube_video_id(link)
    match_data = %r{youtu\.be\/([^?]*)}.match(link) ||
                 %r{youtube\.com\/watch\?.*v=([^?&]*)}.match(link)
    match_data[1]
  end

  def youtube_start_time(link)
    match_data = /t=(\d+)s/.match(link)
    match_data.nil? ? 0 : match_data[1].to_i
  end
end
