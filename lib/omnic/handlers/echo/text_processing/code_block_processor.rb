# code_block_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class CodeBlockProcessor < SimplePatternProcessor
  def pattern
    /```.+```/
  end

  def to_html(code_block)
    "<div><code>#{code_block.gsub('```', '')}</code></div>"
  end
end
