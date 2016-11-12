# greeting_handler.rb
#
# Author::	Kyle Mullins

class GreetingHandler < CommandHandler
  command :hi, :greet, description: 'Say hello to your friendly neighborhood Omnic.'

  def greet(event)
    "Hello, #{event.user.mention}! :wave:"
  end
end
