# user_mention_processor.rb
#
# Author::  Kyle Mullins

require_relative 'simple_pattern_processor'

class UserMentionProcessor < SimplePatternProcessor
  def initialize(users)
    @users = users
  end

  def pattern
    /<@[\d!]+>/
  end

  def to_html(mention)
    "<b>#{find_username_for_mention(mention)}</b>"
  end

  def find_username_for_mention(mention)
    mentioned_user = @users.find { |user| mention.include?(user.id.to_s) }

    return mention.gsub(/[<>]/, '') if mentioned_user.nil?

    "@#{mentioned_user.display_name}"
  end
end
