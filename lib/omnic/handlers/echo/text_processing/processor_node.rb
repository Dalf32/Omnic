# processor_node.rb
#
# Author::  Kyle Mullins

class ProcessorNode
  attr_reader :next_node

  HtmlElement = Struct.new(:html)

  def initialize(next_node: nil)
    @next_node = next_node
  end

  def link_node(next_node)
    @next_node = next_node
    self
  end

  def next_node?
    !@next_node.nil?
  end

  def process(*input)
    input.map do |input_part|
      next unless input_part.is_a?(String)

      process_part(input_part)
    end.flatten
  end

  protected

  def process_part(input_part)
    pass(input_part)
  end

  def pass(input)
    if next_node?
      @next_node.process(input)
    else
      input
    end
  end
end
