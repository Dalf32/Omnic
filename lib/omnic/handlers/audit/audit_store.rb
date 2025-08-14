# audit_store.rb
#
# AUTHOR::  Kyle Mullins

class AuditStore
  def initialize(server_redis, message_cache_time)
    @redis = server_redis
    @message_cache_time = message_cache_time
  end

  def enabled?
    @message_cache_time.positive?
  end

  def channel_set?
    @redis.exists?(:audit_channel)
  end

  def can_encrypt?
    !Omnic.encryption.nil?
  end

  def should_cache?
    enabled? && channel_set? && can_encrypt?
  end

  def clear_channel
    @redis.del(:audit_channel)
  end

  def channel
    @redis.get(:audit_channel)
  end

  def channel=(channel_id)
    @redis.set(:audit_channel, channel_id)
  end

  def cache_message(message)
    cache_key = cache_key(message.id)
    text = can_encrypt? ? Omnic.encryption.encrypt(message.text) : message.text
    text = text.force_encoding('UTF-8')
    @redis.hmset(cache_key, :author, message.author.distinct, :text, text,
                 :pinned, message.pinned?, :has_embed, message.embeds.any?)
    @redis.expire(cache_key, @message_cache_time * 60)
  end

  def cached_message(message_id)
    cache_key = cache_key(message_id)

    if @redis.exists?(cache_key)
      return @redis.hgetall(cache_key).to_h.tap do |result|
        if can_encrypt?
          encrypted = result['text'].force_encoding('ASCII-8BIT')
          result['text'] = Omnic.encryption.decrypt(encrypted).force_encoding('UTF-8')
          result['message_available'] = true
        end
      end
    end

    default_text = '*[Message Unavailable]*'
    { 'text' => default_text, 'author' => default_text,
      'message_available' => false }
  end

  private

  def cache_key(message_id)
    "message_cache:#{message_id}"
  end
end
