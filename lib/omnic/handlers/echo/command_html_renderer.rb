# command_html_renderer.rb
#
# Author::  Kyle Mullins

require 'erb'

class CommandHtmlRenderer
  attr_reader :prefix, :server, :table_rows

  def initialize(template_file)
    @template = open(template_file).readlines.join
  end

  def command_prefix(prefix)
    @prefix = prefix
    self
  end

  def server_name(server_name)
    @server = server_name
    self
  end

  def commands(commands)
    @table_rows = commands.each_slice(4).to_a
    self
  end

  def render
    ERB.new(@template).result(binding)
  end

  private

  def render_command(command)
    if command.image?
      "<img src=\"#{command.image_url}\">"
    elsif command.youtube?
      "<iframe src=\"#{command.youtube_embed_url}\" frameborder=\"0\" allowfullscreen></iframe>"
    elsif command.code?
      "<div><code>#{command.reply}</code></div>"
    elsif command.video?
      "<video controls><source src=\"#{command.video_url}\" type=\"#{command.video_type}\"></video>"
    else
      command.reply
    end
  end
end
