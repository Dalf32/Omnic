# plaintext_processor.rb
#
# Author::  Kyle Mullins

require_relative 'processor_node'

class PlaintextProcessor < ProcessorNode
  def process_part(input_part)
    HtmlElement.new(input_part.gsub("\r\n", '<br>').gsub("\n", '<br>'))
  end
end
