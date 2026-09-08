---
name: action-cable
description: Expert guidance for implementing real-time features with Action Cable in Rails applications. Use when working with websockets, channels, subscriptions, broadcasting, live updates, push notifications, or Solid Cable. Covers connection authentication, channel creation, streaming, client-side JS, testing, and deployment. Clarifies when to use Action Cable directly vs Turbo Streams broadcasting.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate channel:*), Bash(bin/rails generate channel), Bash(bin/rails solid_cable:install), Bash(bundle exec rails generate channel)
---

# Rails Action Cable Expert

Build real-time WebSocket features in Rails using Action Cable — channels, subscriptions, broadcasting, and Solid Cable.

## Critical Decision: Action Cable vs Turbo Streams

**Before writing ANY Action Cable code, ask: would Turbo Streams solve this?**

### Use Turbo Streams Broadcasting (NOT raw Action Cable) When:
- Broadcasting model changes (create/update/destroy) to update page fragments
- Simple "something changed, update this part of the page" scenarios
- CRUD-driven real-time updates (chat messages, comments, notifications list)
- You want automatic DOM updates without writing JavaScript

```ruby
# This is Turbo Streams — NOT raw Action Cable. Prefer this.
class Message < ApplicationRecord
  broadcasts_to :room  # That's it. No channel file needed.
end
```

### Use Raw Action Cable When:
- **Custom client-side behavior** — you need `received()` callback logic beyond DOM replacement
- **Bidirectional communication** — client sends data TO server via `perform()` / `send()`
- **Presence/typing indicators** — tracking who's online, who's typing
- **Non-HTML payloads** — sending JSON data, coordinates, game state
- **Progress tracking** — file upload progress, job status updates
- **External integrations** — piping data from external WebSocket sources
- **Fine-grained stream control** — dynamic subscribe/unsubscribe based on user actions

**Rule of thumb:** If you're just broadcasting HTML to replace/append DOM elements after a model callback, use Turbo Streams. If you need custom JavaScript handling or bidirectional communication, use Action Cable.

## When To Use This Skill

- Setting up WebSocket connections and channels
- Implementing real-time features (chat, notifications, presence, live dashboards)
- Configuring Solid Cable, Redis, or PostgreSQL adapters
- Authenticating WebSocket connections
- Writing client-side channel subscriptions
- Testing Action Cable channels
- Deploying Action Cable in production

## Instructions

### Step 1: Check Existing Setup

```bash
# Check if Action Cable is already configured
cat config/cable.yml
ls app/channels/application_cable/

# Check for existing channels
ls app/channels/
ls app/javascript/channels/ 2>/dev/null

# Check if Turbo is present (prefer Turbo Streams if so)
grep -r "turbo-rails" Gemfile
grep -r "broadcasts" app/models/
```

**Match existing project conventions.** If the app already uses Turbo Streams broadcasting, don't introduce raw Action Cable for something Turbo handles.

### Step 2: Set Up Connection Authentication

**ALWAYS authenticate connections. Never skip this.**

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        # Cookie-based auth (most common with Devise/standard Rails auth)
        if verified_user = User.find_by(id: cookies.encrypted[:user_id])
          verified_user
        else
          reject_unauthorized_connection
        end
      end
  end
end
```

**Auth patterns by setup:**

| Auth Method | Implementation |
|-------------|---------------|
| Cookie/session (default) | `cookies.encrypted[:user_id]` or `cookies.encrypted["_session"]["user_id"]` |
| Devise | `env["warden"].user` or `cookies.signed["user.id"]` |
| Token-based (API) | Pass token via query param: `createConsumer(\`/cable?token=\${token}\`)` |

**Common mistake:** Leaving `connect` empty or not calling `reject_unauthorized_connection`. This lets unauthenticated users subscribe to any channel.

### Step 3: Create Channels

Use the generator:
```bash
bin/rails generate channel Chat
```

This creates:
- `app/channels/chat_channel.rb` — server-side channel
- `app/javascript/channels/chat_channel.js` — client-side subscription (if using importmap/jsbundling)
- Test file

**Channel with streams:**

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    # stream_from — string-based stream name (manual)
    stream_from "chat_#{params[:room_id]}"

    # OR stream_for — model-based stream name (preferred for model association)
    # room = Room.find(params[:room_id])
    # stream_for room
  end

  def unsubscribed
    # Cleanup when client disconnects
  end

  # Custom actions callable from client via perform()
  def speak(data)
    Message.create!(
      room_id: params[:room_id],
      user: current_user,
      body: data["body"]
    )
  end
end
```

### Step 4: Choose Stream Type

**`stream_from` vs `stream_for`:**

| Method | Use When | Stream Name |
|--------|----------|-------------|
| `stream_from "chat_#{id}"` | Manual string control, non-model streams | You define it |
| `stream_for room` | Model-based streams, pairs with `broadcast_to` | Auto-generated from GlobalID |

**Prefer `stream_for`** when the stream maps to a model. It's safer (uses GlobalID, not guessable IDs) and pairs naturally with `broadcast_to`.

```ruby
# stream_for + broadcast_to (preferred for model streams)
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# Broadcasting from anywhere:
NotificationsChannel.broadcast_to(user, { title: "New message", body: "..." })

# stream_from + broadcast (for non-model or shared streams)
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard_#{params[:team_id]}"
  end
end

# Broadcasting from anywhere:
ActionCable.server.broadcast("dashboard_#{team.id}", { metric: "users", value: 42 })
```

### Step 5: Client-Side Subscription

```js
// app/javascript/channels/consumer.js
import { createConsumer } from "@rails/actioncable"
export default createConsumer()
```

```js
// app/javascript/channels/chat_channel.js
import consumer from "./consumer"

const chatChannel = consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: roomId },
  {
    // Called when subscription is confirmed by server
    connected() {
      console.log("Connected to chat")
    },

    // Called when WebSocket closes
    disconnected() {
      console.log("Disconnected from chat")
    },

    // Called when server broadcasts data
    received(data) {
      const messagesEl = document.getElementById("messages")
      messagesEl.insertAdjacentHTML("beforeend", data.html)
    },

    // Custom method — calls server-side ChatChannel#speak
    speak(body) {
      this.perform("speak", { body: body })
    }
  }
)
```

**Key client callbacks:**
- `connected()` — subscription confirmed, WebSocket open
- `disconnected()` — WebSocket closed (network issue, server restart)
- `received(data)` — server sent data via broadcast
- `rejected()` — server rejected the subscription
- `this.perform("action", data)` — call server-side channel method
- `this.send(data)` — send raw data (requires server-side `receive` method)

### Step 6: Broadcasting

**From models/controllers/jobs:**

```ruby
# Using broadcast (string stream name)
ActionCable.server.broadcast("chat_#{room.id}", {
  html: render_to_string(partial: "messages/message", locals: { message: message }),
  sent_by: message.user.name
})

# Using broadcast_to (model stream — pairs with stream_for)
ChatChannel.broadcast_to(room, {
  html: render_to_string(partial: "messages/message", locals: { message: message }),
  sent_by: message.user.name
})
```

**Common mistake:** Broadcasting too much data. Send only what the client needs. Prefer rendered HTML partials or minimal JSON — not entire model attributes with associations.

**Broadcast from a background job** for heavy rendering:

```ruby
class MessageBroadcastJob < ApplicationJob
  def perform(message)
    html = ApplicationController.renderer.render(
      partial: "messages/message",
      locals: { message: message }
    )
    ActionCable.server.broadcast("chat_#{message.room_id}", { html: html })
  end
end
```

### Step 7: Configure the Adapter

**Rails 8 default: Solid Cable (database-backed, no Redis needed)**

```bash
bin/rails solid_cable:install
```

This sets up `config/cable.yml` and creates `db/cable_schema.rb`. Update `config/database.yml` to add the cable database.

**config/cable.yml — quick setup:**

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

**Adapter options:** Solid Cable (default, database-backed), Redis (highest throughput), PostgreSQL (8KB payload limit). See `references/adapters-config.md` for full adapter comparison and configuration examples.

### Step 8: Production Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Mount path (default: /cable)
  config.action_cable.mount_path = "/cable"

  # Allowed origins (REQUIRED in production)
  config.action_cable.allowed_request_origins = [
    "https://yourdomain.com",
    %r{https://.*\.yourdomain\.com}
  ]

  # Worker pool (match to available DB connections)
  config.action_cable.worker_pool_size = 4

  # URL for standalone cable server (if separated)
  # config.action_cable.url = "wss://cable.yourdomain.com"
end
```

**Add the meta tag to your layout:**

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <%= action_cable_meta_tag %>
</head>
```

### Step 9: Handle Disconnections

**Server-side cleanup:**

```ruby
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence"
    current_user.update!(online: true)
  end

  def unsubscribed
    current_user.update!(online: false)
  end
end
```

**Client-side reconnection is automatic.** Action Cable reconnects with exponential backoff. But handle the UI state:

```js
connected() {
  document.getElementById("status").textContent = "Connected"
},

disconnected() {
  document.getElementById("status").textContent = "Reconnecting..."
}
```

**Common mistake:** Not implementing `unsubscribed` when tracking presence or holding resources. Always clean up.

### Step 10: Testing

**Channel test (unit):**

```ruby
class ChatChannelTest < ActionCable::Channel::TestCase
  test "subscribes to room stream" do
    subscribe room_id: rooms(:general).id
    assert subscription.confirmed?
    assert_has_stream "chat_#{rooms(:general).id}"
  end

  test "rejects without room_id" do
    subscribe room_id: nil
    assert subscription.rejected?
  end
end
```

See `references/testing.md` for connection tests, `stream_for` assertions, and broadcast assertion patterns.

## Quick Reference

### Generator

```bash
bin/rails generate channel ChannelName [action1 action2]
# Example:
bin/rails generate channel Chat speak
```

### Server-Side API

```ruby
# Stream methods (in subscribed)
stream_from "stream_name"                    # String-based stream
stream_for model_instance                    # Model-based stream (GlobalID)

# Broadcasting (from anywhere)
ActionCable.server.broadcast("stream_name", data)   # To string stream
MyChannel.broadcast_to(model_instance, data)         # To model stream

# Connection identifiers
identified_by :current_user                  # In Connection class
current_user                                 # Available in channels

# Reject
reject                                       # Reject subscription (in subscribed)
reject_unauthorized_connection               # Reject connection (in connect)

# Disconnect a user (from anywhere)
ActionCable.server.remote_connections.where(current_user: user).disconnect
```

### Client-Side API

```js
// Create subscription
const sub = consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: 1 },
  { connected() {}, disconnected() {}, received(data) {} }
)

// Call server action
sub.perform("speak", { body: "Hello" })

// Send raw data (needs server `receive` method)
sub.send({ body: "Hello" })

// Unsubscribe
sub.unsubscribe()

// Enable logging
ActionCable.logger.enabled = true
```

### Stimulus + Action Cable Pattern

See `references/client-side.md` for the full Stimulus + Action Cable integration pattern with controller example.

## Anti-Patterns to Avoid

1. **Using Action Cable when Turbo Streams suffices** — if you just need model-change broadcasts with DOM updates, use `broadcasts_to` on the model
2. **Unauthenticated connections** — always implement `connect` with `reject_unauthorized_connection`
3. **Broadcasting entire models** — send minimal data or pre-rendered HTML, not `model.as_json`
4. **No `unsubscribed` cleanup** — if you track state in `subscribed`, clean it up in `unsubscribed`
5. **Synchronous heavy work in channels** — use background jobs for expensive broadcasts
6. **Using `async` adapter in production** — it's single-process only; use Solid Cable or Redis
7. **Missing `allowed_request_origins`** — required in production to prevent cross-origin hijacking
8. **String interpolation with user input in stream names** — validate/sanitize params before `stream_from "chat_#{params[:room]}"`
9. **Not handling `disconnected()` on client** — users need visual feedback when connection drops
10. **Creating channels without the generator** — `bin/rails generate channel` sets up both server and client files correctly

## Debugging Tips

```ruby
# Server-side: check active connections
ActionCable.server.connections.length

# Server-side: log tags for debugging
# config/environments/development.rb
config.action_cable.log_tags = [
  -> request { request.env["user_account_id"] || "no-account" },
  :action_cable,
  -> request { request.uuid }
]
```

```js
// Client-side: enable logging
import * as ActionCable from "@rails/actioncable"
ActionCable.logger.enabled = true

// Check connection state
consumer.connection.isOpen()
consumer.connection.isActive()
```

```bash
# Check cable config
cat config/cable.yml

# Verify WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" \
  http://localhost:3000/cable
```

See the `references/` directory for detailed patterns, edge cases, and advanced configurations:
- `references/connection-auth.md` — Authentication patterns (Devise, token, JWT, multi-identifier)
- `references/channels.md` — Channel patterns, callbacks, dynamic streams
- `references/broadcasting.md` — Broadcasting from models, controllers, targeted/conditional
- `references/client-side.md` — Stimulus integration, reconnection, Turbo Streams comparison
- `references/adapters-config.md` — Solid Cable, Redis, PostgreSQL config, deployment
- `references/testing.md` — Channel, connection, broadcast, and system test patterns
- `references/patterns.md` — Presence, typing indicators, progress tracking, error handling, security
