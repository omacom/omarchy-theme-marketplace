# Edge Cases, Gotchas & Stimulus Integration

Common pitfalls, Turbo+Stimulus patterns, and important behavioral details.

---

## Turbo + Stimulus Integration

Turbo and Stimulus complement each other. Turbo handles HTML delivery; Stimulus handles client-side behavior.

### Auto-Dismiss Flash Messages

```erb
<div data-controller="auto-dismiss" data-auto-dismiss-delay-value="3000">
  <div class="flash">Post created!</div>
</div>
```

```javascript
// app/javascript/controllers/auto_dismiss_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 3000 } }

  connect() {
    this.timeout = setTimeout(() => {
      this.element.remove()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

### Form Submission with Loading State

```erb
<%= form_with model: @post, data: { controller: "submit-button" } do |f| %>
  <%= f.text_field :title %>
  <%= f.submit "Save", data: { submit_button_target: "button", action: "submit->submit-button#disable" } %>
<% end %>
```

### Turbo Events in Stimulus

```javascript
// Listen for Turbo events in a Stimulus controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Turbo Frame loaded
    this.element.addEventListener("turbo:frame-load", this.onFrameLoad.bind(this))

    // Before Turbo Stream action
    document.addEventListener("turbo:before-stream-render", this.onBeforeStream.bind(this))
  }

  onFrameLoad(event) {
    // Frame content was replaced
    console.log("Frame loaded:", event.target.id)
  }

  onBeforeStream(event) {
    // Customize stream behavior
    const { action, target } = event.detail.newStream
    console.log(`Stream: ${action} → ${target}`)
  }
}
```

### Key Turbo Events

| Event | When | Use For |
|-------|------|---------|
| `turbo:load` | Page load (Drive) | Initialize page-level JS |
| `turbo:frame-load` | Frame content loaded | Post-load setup for frame content |
| `turbo:before-stream-render` | Before stream action | Custom stream behavior |
| `turbo:submit-start` | Form submit begins | Show loading state |
| `turbo:submit-end` | Form submit completes | Hide loading state |
| `turbo:before-fetch-request` | Before any Turbo fetch | Add headers, modify request |
| `turbo:before-fetch-response` | Before processing response | Inspect/modify response |

---

## Edge Cases and Gotchas

### 1. Frame Requests Include a `Turbo-Frame` Header

The server can detect frame requests:
```ruby
def show
  if turbo_frame_request?
    # Only render the minimal content needed for the frame
    render partial: "post_detail", locals: { post: @post }
  else
    # Full page render
  end
end
```

But **you usually don't need this.** Just include matching `turbo_frame_tag` in your normal views.

### 2. Turbo Caching and Preview

Turbo Drive caches pages for back/forward navigation. This can show stale content.

```erb
<%# Disable caching for this page %>
<meta name="turbo-cache-control" content="no-cache">

<%# Or no-preview (don't show cached version while loading) %>
<meta name="turbo-cache-control" content="no-preview">
```

### 3. File Uploads

Standard file uploads break with Turbo. Options:

```erb
<%# Option A: Disable Turbo for the form %>
<%= form_with model: @document, data: { turbo: false } do |f| %>
  <%= f.file_field :attachment %>
<% end %>

<%# Option B: Use Active Storage direct upload (works with Turbo) %>
<%= form_with model: @document do |f| %>
  <%= f.file_field :attachment, direct_upload: true %>
<% end %>
```

### 4. Redirect After DELETE

```ruby
def destroy
  @post.destroy

  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@post)) }
    format.html { redirect_to posts_path, status: :see_other }  # ← 303, not 302!
  end
end
```

**`status: :see_other` (303) is required for DELETE redirects with Turbo.** A 302 redirect after DELETE will try to DELETE the redirect target. 303 forces a GET.

### 5. Custom Turbo Stream Actions

You can define custom actions beyond the 7 built-in ones:

```javascript
// app/javascript/application.js
import { StreamActions } from "@hotwired/turbo"

// Custom "log" action
StreamActions.log = function() {
  console.log(this.getAttribute("message"))
}

// Custom "redirect" action
StreamActions.redirect = function() {
  Turbo.visit(this.getAttribute("url"))
}
```

```erb
<%# Use in a template %>
<turbo-stream action="redirect" url="<%= posts_path %>"></turbo-stream>

<%# Or from Ruby %>
<%= turbo_stream.action(:redirect, url: posts_path) %>
```

### 6. Turbo Streams over SSE (Server-Sent Events)

Alternative to WebSockets for broadcasting:

```ruby
# config/cable.yml
# Use async adapter for development, Redis for production
development:
  adapter: async

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
```

### 7. Signed Stream Names (Security)

`turbo_stream_from` uses signed stream names to prevent unauthorized subscriptions:

```erb
<%# This is safe — stream name is signed server-side %>
<%= turbo_stream_from current_user %>

<%# For custom verification: %>
<%= turbo_stream_from current_user, :notifications %>
```

### 8. Handling Race Conditions in Broadcasts

Broadcasts from `after_create_commit` can fire before the transaction is fully visible to other database connections (especially with replicas):

```ruby
# If you see missing records in broadcast partials, add a small delay:
after_create_commit do
  broadcast_append_later_to("posts",
    target: "posts_list",
    partial: "posts/post")
end
```

`broadcast_*_later_to` methods use Active Job, which adds a natural delay.

### 9. CSRF Tokens and Turbo

Turbo automatically includes CSRF tokens in form submissions. But if you're making custom fetch requests alongside Turbo:

```javascript
// Get the CSRF token
const token = document.head.querySelector("meta[name=csrf-token]")?.content

fetch("/posts", {
  method: "POST",
  headers: {
    "X-CSRF-Token": token,
    "Content-Type": "application/json",
    "Accept": "text/vnd.turbo-stream.html"  // Request Turbo Stream response
  },
  body: JSON.stringify({ post: { title: "Test" } })
})
```

### 10. Frame Loading States

Style frames during loading:

```css
turbo-frame {
  /* While loading (has src, hasn't loaded yet) */
  &[busy] {
    opacity: 0.5;
    pointer-events: none;
  }
}

/* Or target the loading placeholder */
turbo-frame:not([complete]) .loading-indicator {
  display: block;
}
```

### 11. Preventing Double Submissions

Turbo automatically disables submit buttons during submission. But for custom buttons:

```erb
<%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

This changes the button text to "Saving..." and disables it during submission.

### 12. Turbo Native (Mobile Apps)

If your Rails app serves a Turbo Native iOS/Android app, some patterns change:

```ruby
# Detect Turbo Native requests
if turbo_native_app?
  # Return minimal chrome, no nav bar, etc.
  render layout: "turbo_native"
end
```

### 13. Content Security Policy (CSP)

Turbo Streams use inline `<turbo-stream>` elements. If your CSP blocks inline scripts, you may need:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  # Turbo doesn't use inline scripts, but some custom actions might
  policy.script_src :self
end
```

### 14. Request Format Precedence

When both `format.turbo_stream` and `format.html` are defined:
- **Turbo form submission** → picks `turbo_stream` (Turbo sends `Accept: text/vnd.turbo-stream.html`)
- **Direct browser navigation** → picks `html`
- **JavaScript `fetch`** → depends on your `Accept` header

Always define both for graceful degradation:
```ruby
respond_to do |format|
  format.turbo_stream { ... }  # Turbo-enhanced
  format.html { ... }          # Fallback
end
```
