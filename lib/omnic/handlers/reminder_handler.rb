# reminder_handler.rb
#
# Author::  Kyle Mullins

require 'chronic_duration'

class ReminderHandler < CommandHandler
  feature :reminders, default_enabled: true

  command :remindmein, :remind_me_in, feature: :reminders, min_args: 1,
      usage: 'remindmein <time_expr>',
      description: 'Reminds you of something in the given amount of time.'
  # TODO: command :remindmeat

  event :ready, :start_reminder_thread

  def config_name
    :reminders
  end

  def redis_name
    :reminders
  end

  def remind_me_in(event, *time_expr)
    time_str = time_expr.join(' ')
    time_secs = ChronicDuration.parse(time_str, keep_zero: true).truncate
    return "Invalid time: #{time_str}" if time_secs.zero?
    return "Time too large: #{time_str}" if time_secs >= 2_147_483_647

    prompt_for_message(event, time_secs)

    nil
  end

  def start_reminder_thread(_event)
    thread(:reminder_thread, &method(:check_reminders))
  end

  private

  def check_reminders
    loop do
      global_redis.smembers('ids').each do |reminder_id|
        send_reminder(reminder_id) unless global_redis.exists("timers:#{reminder_id}")
      end

      sleep_reminder_thread
    end
  end

  def prompt_for_message(event, time_secs)
    max_wait_time = config.key?(:max_response_time) ? config.max_response_time : 300
    cutoff_time = Time.now + max_wait_time

    event.message.reply('What would you like your reminder to say?')
    event.message.await(event.message.id, after: cutoff_time) do |await_event|
      pretty_time = ChronicDuration.output(time_secs)
      await_event.message.reply("OK, got it! I'll remind you in #{pretty_time}")

      create_reminder(event.message.id, time_secs,
                      event.author, await_event.message.text)
    end
  end

  def create_reminder(reminder_id, time_secs, user, message)
    log.info("Creating reminder for User [#{user.name}:#{user.id}]")

    global_redis.setex("timers:#{reminder_id}", time_secs, 'timer')
    global_redis.hmset("details:#{reminder_id}",
                       'user_id', user.id,
                       'message', message)
    global_redis.sadd('ids', reminder_id)
  end

  def send_reminder(reminder_id)
    reminder_details = Hash[*global_redis.hgetall("details:#{reminder_id}").flatten]
    user = bot.user(reminder_details['user_id'])

    return unless bot.connected?

    log.info("Sending reminder to User [#{user.name}:#{user.id}]")

    message = reminder_details['message'].encode('utf-8-hfs', 'utf-8')
    user.pm("Reminder: #{message}")

    global_redis.srem('ids', reminder_id)
    global_redis.del("details:#{reminder_id}")
  end

  def sleep_reminder_thread
    sleep_time = config.key?(:sleep_interval) ? config.sleep_interval : 5

    log.debug("Sleeping Reminders thread for #{sleep_time}s")

    sleep(sleep_time)
  end
end
