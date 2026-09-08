# Morph Refresh Patterns

Turbo 8+ morphing — DOM diffing for smooth page updates that preserve client state.

---

## Basic Morph Setup (Rails 8+)

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
</head>
```

## Model-Driven Refresh

```ruby
class Post < ApplicationRecord
  # Broadcast a page refresh (instead of granular stream actions)
  broadcasts_refreshes

  # Or manually:
  after_update_commit { broadcast_refresh_to "posts" }
end
```

## Preserving Elements Across Morphs

```erb
<%# Video player, audio, maps — anything with client-side state %>
<div id="video_player" data-turbo-permanent>
  <video src="<%= @video.url %>" autoplay></video>
</div>

<%# Form inputs are automatically preserved during morph if they have focus %>
```

## When Morph is Better Than Streams

| Scenario | Use Morph | Use Streams |
|----------|-----------|-------------|
| Dashboard with many counters | ✅ Re-render whole page | ❌ Too many stream targets |
| Chat messages | ❌ Full page refresh wasteful | ✅ Append single message |
| Kanban board reorder | ✅ Morph preserves drag state | ❌ Complex multi-target streams |
| Single field update | ❌ Overkill | ✅ Targeted update |
