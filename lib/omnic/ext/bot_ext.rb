# bot_ext.rb
#
# Author::	Kyle Mullins

module BotExt
    def send_message(channel_id, content, tts = false, embed = nil)
      content.scan(/.{1,2000}/m).map{ |split_content| super(channel_id, split_content, tts, embed) }.last
    end
end
