# simple_pattern_processor.rb
#
# Author::  Kyle Mullins

require_relative 'processor_node'

class SimplePatternProcessor < ProcessorNode
  def process_part(input_part)
    matches = input_part.scan(pattern).select { |match| filter(match) }

    return pass(input_part) if matches.empty?

    cur_str = input_part
    final_parts = []

    matches.each do |match|
      head, cur_str = *cur_str.split(match, 2)
      final_parts << pass(head) unless head.empty?
      final_parts << HtmlElement.new(to_html(match))
    end

    final_parts << pass(cur_str) unless cur_str.empty?
    final_parts
  end

  protected

  def pattern
    /.*/
  end

  def filter(_match)
    true
  end

  def to_html(match)
    match
  end
end
