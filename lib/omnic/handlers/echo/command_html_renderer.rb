# command_html_renderer.rb
#
# Author::  Kyle Mullins

require 'erb'

require_relative 'text_processing/code_block_processor'
require_relative 'text_processing/image_link_processor'
require_relative 'text_processing/youtube_link_processor'
require_relative 'text_processing/video_link_processor'
require_relative 'text_processing/bare_link_processor'
require_relative 'text_processing/user_mention_processor'
require_relative 'text_processing/plaintext_processor'

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

  def users(users)
    @users = users
    self
  end

  def render
    ERB.new(@template).result(binding)
  end

  private

  def render_command(command)
    process_chain.process(command.reply).map(&:html).join
  end

  def process_chain
    @process_chain ||= CodeBlockProcessor.new
                                         .link_node(VideoLinkProcessor.new
                                         .link_node(ImageLinkProcessor.new
                                         .link_node(YoutubeLinkProcessor.new
                                         .link_node(BareLinkProcessor.new
                                         .link_node(UserMentionProcessor.new(@users)
                                         .link_node(PlaintextProcessor.new))))))
  end
end
