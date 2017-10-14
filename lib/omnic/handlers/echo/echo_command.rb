# echo_command.rb
#
# Author::  Kyle Mullins

class EchoCommand
  attr_reader :name

  def initialize(name, reply)
    @name = name
    @reply = reply
  end

  def image?
    /(\.jpg|\.png|\.gif|imgur\.com|gfycat\.com)/ === @reply
  end

  def youtube?
    /(youtu\.be|youtube\.com)/ === @reply
  end

  def code?
    /```/ === @reply
  end

  def video?
    /(\.webm|\.ogg|\.mp4)/ === @reply
  end

  def reply
    @reply.gsub('```', '')
  end

  def image_url
    if @reply.include?('imgur.com') && @reply !~ /\.[a-z]+$/
      @reply + '.gif'
    elsif @reply.include?('gfycat.com') && @reply !~ /\.[a-z]+$/
      "https://giant.gfycat.com/#{@reply.split('/')[-1]}.gif"
    else
      @reply
    end
  end

  def youtube_embed_url
    video_id = youtube_video_id
    start_time = youtube_start_time
    args = start_time.zero? ? '' : "?start=#{start_time}"
    "https://www.youtube.com/embed/#{video_id}#{args}"
  end

  def video_url
    @reply
  end

  def video_type
    case @reply
    when /\.mp4/
      'video/mp4'
    when /\.webm/
      'video/webm'
    when /\.ogg/
      'video/ogg'
    else
      'video/mp4'
    end
  end

  private

  def youtube_video_id
    match_data = %r{youtu\.be\/([^?]*)}.match(@reply) ||
                 %r{youtube\.com\/watch\?.*v=([^?&]*)}.match(@reply)
    match_data[1]
  end

  def youtube_start_time
    match_data = /t=(\d+)s/.match(@reply)
    match_data.nil? ? 0 : match_data[1].to_i
  end
end
