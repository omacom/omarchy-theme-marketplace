# Client-Side Patterns

## Stimulus Controller Integration

This is the modern Rails way — pair Action Cable subscriptions with Stimulus controllers.

```js
// app/javascript/controllers/notifications_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["badge", "list"]

  connect() {
    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      received: this.handleNotification.bind(this)
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  handleNotification(data) {
    // Update badge count
    if (this.hasBadgeTarget) {
      const count = parseInt(this.badgeTarget.textContent || "0") + 1
      this.badgeTarget.textContent = count
      this.badgeTarget.classList.remove("hidden")
    }

    // Prepend notification to list
    if (this.hasListTarget) {
      this.listTarget.insertAdjacentHTML("afterbegin", data.html)
    }
  }
}
```

```erb
<!-- app/views/layouts/application.html.erb -->
<div data-controller="notifications">
  <span data-notifications-target="badge" class="hidden">0</span>
  <div data-notifications-target="list"></div>
</div>
```

## Reconnection Handling

Action Cable handles reconnection automatically with exponential backoff. Handle the UI:

```js
consumer.subscriptions.create("ChatChannel", {
  connected() {
    this.showStatus("connected")
    // Re-fetch missed messages on reconnect
    this.fetchMissedMessages()
  },

  disconnected() {
    this.showStatus("disconnected")
  },

  rejected() {
    this.showStatus("unauthorized")
    // Redirect to login
    window.location.href = "/login"
  },

  showStatus(status) {
    const el = document.getElementById("connection-status")
    if (el) {
      el.dataset.status = status
      el.textContent = status === "connected" ? "●" : "○"
    }
  },

  fetchMissedMessages() {
    const lastId = document.querySelector("[data-message-id]:last-child")?.dataset.messageId
    if (lastId) {
      fetch(`/messages?after=${lastId}`)
        .then(r => r.json())
        .then(messages => messages.forEach(m => this.received(m)))
    }
  }
})
```

## Multiple Subscriptions

```js
// Subscribe to multiple rooms
const rooms = [1, 2, 3]
const subscriptions = rooms.map(roomId =>
  consumer.subscriptions.create(
    { channel: "ChatChannel", room_id: roomId },
    {
      received(data) {
        document.querySelector(`#room-${roomId}-messages`)
          .insertAdjacentHTML("beforeend", data.html)
      }
    }
  )
)

// Unsubscribe from all
subscriptions.forEach(sub => sub.unsubscribe())
```

## Turbo Streams vs Action Cable Decision Matrix

| Scenario | Use Turbo Streams | Use Action Cable |
|----------|:-:|:-:|
| New record appears on page | ✅ | |
| Record updated, reflect on page | ✅ | |
| Record deleted, remove from page | ✅ | |
| Chat messages (simple display) | ✅ | |
| Chat with typing indicators | | ✅ |
| Online/offline presence | | ✅ |
| Live dashboard with custom charts | | ✅ |
| Progress bar updates | | ✅ |
| Multiplayer game state | | ✅ |
| Notifications (HTML badge) | ✅ | |
| Notifications (browser Notification API) | | ✅ |
| Collaborative editing cursors | | ✅ |
| Live search/autocomplete | | ✅ |
| Model CRUD → page update | ✅ | |
| Client sends data to server | | ✅ |

### Turbo Streams Broadcasting Quick Reference

For comparison, here's how Turbo Streams handles the common case:

```ruby
# Model
class Message < ApplicationRecord
  broadcasts_to :room
end

# View — subscribes automatically
<%= turbo_stream_from @room %>

# That's it. No channel file, no JavaScript.
```

Action Cable is the transport layer underneath — Turbo Streams just automates the common pattern.
