# Broadcasting Patterns

Real-time Turbo Stream delivery via ActionCable — scoping, targeting, and background jobs.

---

## Scoped Broadcasts (Multi-Tenant Safe)

```ruby
class Message < ApplicationRecord
  belongs_to :room

  # Broadcast to room-specific stream
  broadcasts_to :room

  # Equivalent to:
  # after_create_commit  { broadcast_append_to(room) }
  # after_update_commit  { broadcast_replace_to(room) }
  # after_destroy_commit { broadcast_remove_to(room) }
end
```

```erb
<%# Subscribe to this room's messages %>
<%= turbo_stream_from @room %>
```

## Custom Stream Names

```ruby
after_create_commit do
  broadcast_append_to(
    [project, "tasks"],       # Stream name: "projects:123:tasks"
    target: "task_list",
    partial: "tasks/task_row"
  )
end
```

## Broadcast to Specific Users

```ruby
# Notify just one user
after_create_commit do
  broadcast_append_to(
    assignee,                   # User model — stream is "users:456"
    target: "notifications",
    partial: "notifications/notification"
  )
end
```

## Background Job Broadcasts

```ruby
class ImportJob < ApplicationJob
  def perform(import)
    import.rows.each_with_index do |row, i|
      process(row)

      # Update progress bar
      Turbo::StreamsChannel.broadcast_replace_to(
        import,
        target: "import_progress",
        partial: "imports/progress",
        locals: { current: i + 1, total: import.rows.count }
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      import,
      target: "import_status",
      html: "<p class='success'>Import complete!</p>"
    )
  end
end
```

## Suppressing Broadcasts for the Current User

Sometimes you don't want the acting user to receive the broadcast (they already see the change via the HTTP response).

```ruby
# In controller
after_action :suppress_turbo_broadcast, only: [:create, :update]

# Or handle in the partial with a conditional
<%# _message.html.erb %>
<div id="<%= dom_id(message) %>" class="message <%= 'own' if message.user == current_user %>">
  <%= message.body %>
</div>
```
