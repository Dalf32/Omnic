# limits_store.rb
#
# AUTHOR:: Kyle Mullins

class LimitsStore
  def initialize(server_redis)
    @redis = server_redis
  end

  def whitelist_channels(command, channel_ids)
    channel_ids.each { |channel_id| @redis.sadd(limitset_key(CHANNEL, WHITELIST, command), channel_id) }
  end

  def blacklist_channels(command, channel_ids)
    channel_ids.each { |channel_id| @redis.sadd(limitset_key(CHANNEL, BLACKLIST, command), channel_id) }
  end

  def whitelist_role(command, role_id)
    @redis.sadd(limitset_key(ROLE, WHITELIST, command), role_id)
  end

  def blacklist_role(command, role_id)
    @redis.sadd(limitset_key(ROLE, BLACKLIST, command), role_id)
  end

  def whitelisted_channels(command)
    @redis.smembers(limitset_key(CHANNEL, WHITELIST, command))
  end

  def blacklisted_channels(command)
    @redis.smembers(limitset_key(CHANNEL, BLACKLIST, command))
  end

  def whitelisted_roles(command)
    @redis.smembers(limitset_key(ROLE, WHITELIST, command))
  end

  def blacklisted_roles(command)
    @redis.smembers(limitset_key(ROLE, BLACKLIST, command))
  end

  def limited_commands
    @redis.scan_each(match: '*_*list:*').to_a.map { |key| key.split(':').last }
          .uniq.sort
  end

  def clear_limits(command)
    @redis.del(limitset_key(CHANNEL, WHITELIST, command))
    @redis.del(limitset_key(CHANNEL, BLACKLIST, command))
    @redis.del(limitset_key(ROLE, WHITELIST, command))
    @redis.del(limitset_key(ROLE, BLACKLIST, command))
  end

  def allowed_in_channel?(command, channel_id)
    return false if violates_whitelist?(CHANNEL, command, channel_id)
    return false if violates_blacklist?(CHANNEL, command, channel_id)

    true
  end

  def allowed_by_roles?(command, role_ids)
    return false if role_ids.all? { |role_id| violates_whitelist?(ROLE, command, role_id) }
    return false if role_ids.any? { |role_id| violates_blacklist?(ROLE, command, role_id) }

    true
  end

  private

  CHANNEL = 'channel'
  ROLE = 'role'
  WHITELIST = 'whitelist'
  BLACKLIST = 'blacklist'

  def limitset_key(entity_type, limit_type, command)
    raise ArgumentError.new('Invalid entity_type') unless [CHANNEL, ROLE].include?(entity_type)
    raise ArgumentError.new('Invalid limit_type') unless [WHITELIST, BLACKLIST].include?(limit_type)

    "#{entity_type}_#{limit_type}:#{command}"
  end

  def violates_whitelist?(entity_type, command, entity_id)
    whitelist = limitset_key(entity_type, WHITELIST, command)

    @redis.exists?(whitelist) && !@redis.sismember(whitelist, entity_id)
  end

  def violates_blacklist?(entity_type, command, entity_id)
    blacklist = limitset_key(entity_type, BLACKLIST, command)

    @redis.exists?(blacklist) && @redis.sismember(blacklist, entity_id)
  end
end
