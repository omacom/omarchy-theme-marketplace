# Common Patterns

## Presence Tracking

```ruby
# app/channels/presence_channel.rb
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence_#{params[:room_id]}"
    current_user.update!(online: true, last_seen_at: Time.current)
    broadcast_presence
  end

  def unsubscribed
    current_user.update!(online: false)
    broadcast_presence
  end

  def heartbeat
    current_user.touch(:last_seen_at)
  end

  private
    def broadcast_presence
      online_users = User.where(online: true).pluck(:id, :display_name)
      ActionCable.server.broadcast("presence_#{params[:room_id]}", {
        type: "presence",
        users: online_users.map { |id, name| { id: id, name: name } }
      })
    end
end
```

## Typing Indicators

```ruby
# app/channels/typing_channel.rb
class TypingChannel < ApplicationCable::Channel
  def subscribed
    stream_from "typing_#{params[:room_id]}"
  end

  def typing(data)
    ActionCable.server.broadcast("typing_#{params[:room_id]}", {
      user_id: current_user.id,
      user_name: current_user.display_name,
      typing: data["typing"]
    })
  end
end
```

```js
// Client
let typingTimeout
inputEl.addEventListener("input", () => {
  channel.perform("typing", { typing: true })
  clearTimeout(typingTimeout)
  typingTimeout = setTimeout(() => {
    channel.perform("typing", { typing: false })
  }, 2000)
})
```

## Progress Tracking

```ruby
# app/channels/progress_channel.rb
class ProgressChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# In a background job
class ImportJob < ApplicationJob
  def perform(user, file)
    total = count_rows(file)
    file.each_row.with_index do |row, i|
      process_row(row)

      if (i % 100).zero?
        ProgressChannel.broadcast_to(user, {
          job_id: job_id,
          progress: ((i.to_f / total) * 100).round,
          status: "processing"
        })
      end
    end

    ProgressChannel.broadcast_to(user, {
      job_id: job_id,
      progress: 100,
      status: "complete"
    })
  end
end
```

## Admin Dashboard / Live Metrics

```ruby
class MetricsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user.admin?
    stream_from "admin_metrics"
  end
end

# Broadcast from a recurring job
class MetricsBroadcastJob < ApplicationJob
  def perform
    ActionCable.server.broadcast("admin_metrics", {
      active_users: User.where("last_seen_at > ?", 5.minutes.ago).count,
      requests_per_minute: RequestLog.where("created_at > ?", 1.minute.ago).count,
      error_rate: ErrorLog.where("created_at > ?", 5.minutes.ago).count
    })
  end
end
```

## Error Handling

### Connection-Level

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    rescue_from StandardError, with: :report_error

    private
      def report_error(e)
        Rails.error.report(e, handled: true, context: {
          user_id: current_user&.id,
          action: "connection"
        })
      end
  end
end
```

### Channel-Level

```ruby
class ChatChannel < ApplicationCable::Channel
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  def speak(data)
    room = Room.find(params[:room_id])
    room.messages.create!(user: current_user, body: data["body"])
  end

  private
    def record_not_found(error)
      # Transmit error to the specific client
      transmit(type: "error", message: "Resource not found")
    end

    def invalid_record(error)
      transmit(type: "error", message: error.record.errors.full_messages.join(", "))
    end
end
```

### Client-Side Error Display

```js
received(data) {
  if (data.type === "error") {
    this.showError(data.message)
    return
  }
  // Normal message handling
  this.appendMessage(data)
},

showError(message) {
  const el = document.getElementById("cable-errors")
  el.textContent = message
  el.classList.remove("hidden")
  setTimeout(() => el.classList.add("hidden"), 5000)
}
```

## Performance

### Keep Broadcasts Small

```ruby
# BAD — sending entire model with associations
ChatChannel.broadcast_to(room, message.as_json(include: [:user, :attachments]))

# GOOD — send only what's needed
ChatChannel.broadcast_to(room, {
  id: message.id,
  body: message.body,
  user_name: message.user.display_name,
  created_at: message.created_at.iso8601
})

# BETTER — pre-render HTML server-side
ChatChannel.broadcast_to(room, {
  html: ApplicationController.renderer.render(
    partial: "messages/message",
    locals: { message: message }
  )
})
```

### Use Background Jobs for Heavy Broadcasts

```ruby
# BAD — blocking the request
def create
  @message = @room.messages.create!(message_params)
  html = render_to_string(partial: "messages/message", locals: { message: @message })
  ActionCable.server.broadcast("chat_#{@room.id}", { html: html })
  head :created
end

# GOOD — non-blocking
def create
  @message = @room.messages.create!(message_params)
  MessageBroadcastJob.perform_later(@message)
  head :created
end
```

### Worker Pool Sizing

```ruby
# config/environments/production.rb
# Match to your thread count and DB pool
config.action_cable.worker_pool_size = ENV.fetch("CABLE_WORKER_POOL_SIZE", 4).to_i
```

Ensure your database pool is at least `worker_pool_size` + your web thread count.

### Throttling Client Sends

```js
// Debounce rapid client events (e.g., typing, cursor position)
function throttle(fn, delay) {
  let lastCall = 0
  return function(...args) {
    const now = Date.now()
    if (now - lastCall >= delay) {
      lastCall = now
      fn.apply(this, args)
    }
  }
}

const throttledTyping = throttle(() => {
  channel.perform("typing", { typing: true })
}, 500)
```

## Security

### Validate All Channel Params

```ruby
def subscribed
  # NEVER trust params directly
  room = Room.find_by(id: params[:room_id])

  # Authorize access
  if room && current_user.can_access?(room)
    stream_for room
  else
    reject
  end
end
```

### Sanitize Broadcast Data

```ruby
# Avoid broadcasting user-supplied HTML directly
ActionCable.server.broadcast("chat_#{room.id}", {
  body: ActionController::Base.helpers.sanitize(message.body),
  user_name: message.user.display_name
})
```

### Rate Limit Channel Actions

```ruby
class ChatChannel < ApplicationCable::Channel
  def speak(data)
    if rate_limited?
      transmit(type: "error", message: "Too many messages. Slow down.")
      return
    end

    record_action
    Message.create!(user: current_user, body: data["body"], room_id: params[:room_id])
  end

  private
    def rate_limited?
      key = "cable_rate:#{current_user.id}"
      count = Rails.cache.increment(key, 1, expires_in: 1.minute)
      count > 30  # 30 messages per minute
    end

    def record_action
      # Already incremented in rate_limited? check
    end
end
```

### Force Disconnect

```ruby
# Disconnect a specific user from all channels
ActionCable.server.remote_connections.where(current_user: user).disconnect

# Use case: user banned, account deleted, password changed
class User < ApplicationRecord
  after_update :disconnect_cable, if: :saved_change_to_password_digest?

  private
    def disconnect_cable
      ActionCable.server.remote_connections.where(current_user: self).disconnect
    end
end
```

### Allowed Request Origins

```ruby
# config/environments/production.rb
config.action_cable.allowed_request_origins = [
  "https://yourdomain.com",
  %r{https://.*\.yourdomain\.com}
]

# NEVER do this in production:
# config.action_cable.disable_request_forgery_protection = true
```
