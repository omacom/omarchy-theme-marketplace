# Turbo Streams — Patterns & Templates

Implementation patterns for Turbo Stream responses: flash messages, live search, nested forms, counters, toasts, and template conventions.

---

## Flash Messages with Streams

Update flash messages after stream-based form submissions.

```erb
<%# app/views/layouts/application.html.erb %>
<div id="flash_messages">
  <% flash.each do |type, message| %>
    <div class="flash flash-<%= type %>"><%= message %></div>
  <% end %>
</div>
```

```erb
<%# app/views/posts/create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", partial: "posts/post", locals: { post: @post } %>

<%= turbo_stream.update "flash_messages" do %>
  <div class="flash flash-notice">Post created successfully!</div>
<% end %>
```

**Alternative — use a shared partial:**

```erb
<%# app/views/shared/_flash.html.erb %>
<% flash.each do |type, message| %>
  <div class="flash flash-<%= type %>" data-controller="auto-dismiss"><%= message %></div>
<% end %>

<%# In the stream response %>
<%= turbo_stream.update "flash_messages", partial: "shared/flash" %>
```

---

## Live Search / Filtering

Turbo Frames make live search trivial — no JavaScript needed.

```erb
<%# app/views/posts/index.html.erb %>
<%= turbo_frame_tag "search_results" do %>
  <%= form_with url: posts_path, method: :get, data: { turbo_frame: "search_results" } do |f| %>
    <%= f.search_field :q, value: params[:q],
        oninput: "this.form.requestSubmit()",
        placeholder: "Search posts..." %>
  <% end %>

  <div id="posts_list">
    <%= render @posts %>
  </div>
<% end %>
```

**How it works:**
1. User types in search field
2. `oninput` submits the form (GET request)
3. The form targets the `search_results` frame (via `data-turbo-frame`)
4. Server returns filtered results
5. Turbo swaps the frame

**Debounce with Stimulus (optional):**
```erb
<%= f.search_field :q, value: params[:q],
    data: { controller: "debounce", action: "input->debounce#search" } %>
```

**Tip:** Add `data-turbo-action="replace"` to the form to update the URL with search params without creating history entries.

---

## Nested Form Items with Streams

Add/remove nested form fields dynamically.

```erb
<%# Parent form %>
<%= form_with model: @invoice do |f| %>
  <%= f.text_field :number %>
  
  <div id="line_items">
    <%= f.fields_for :line_items do |li| %>
      <%= render "line_item_fields", f: li %>
    <% end %>
  </div>
  
  <%= link_to "Add Line Item", new_line_item_invoice_path(@invoice),
      data: { turbo_method: :post } %>
  
  <%= f.submit %>
<% end %>
```

```ruby
# Controller action that returns a stream with the new fields
def add_line_item
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.append("line_items",
        partial: "line_item_fields",
        locals: { f: nil, index: Time.current.to_i })
    end
  end
end
```

---

## Counter / Badge Updates

Update counts in the navbar or sidebar after actions.

```erb
<%# Layout with a notification badge %>
<nav>
  <span id="unread_count"><%= current_user.unread_notifications_count %></span>
</nav>
```

```erb
<%# After marking a notification as read %>
<%= turbo_stream.replace dom_id(@notification), partial: "notifications/notification",
    locals: { notification: @notification } %>
<%= turbo_stream.update "unread_count", html: current_user.unread_notifications_count.to_s %>
```

**With broadcasts (real-time badge updates):**
```ruby
class Notification < ApplicationRecord
  after_create_commit do
    broadcast_update_to(
      user,  # Stream name scoped to user
      target: "unread_count",
      html: user.unread_notifications_count.to_s
    )
  end
end
```

```erb
<%# Subscribe to user-specific stream %>
<%= turbo_stream_from current_user %>
```

---

## Toast Notifications

Push ephemeral notifications to any user.

```erb
<%# Layout %>
<div id="toasts" class="toast-container"></div>
```

```ruby
# From anywhere — controller, job, model
Turbo::StreamsChannel.broadcast_append_to(
  user,
  target: "toasts",
  partial: "shared/toast",
  locals: { message: "New message from #{sender.name}", type: "info" }
)
```

```erb
<%# app/views/shared/_toast.html.erb %>
<div class="toast toast-<%= type %>" data-controller="auto-dismiss" data-auto-dismiss-delay-value="5000">
  <%= message %>
</div>
```

---

## Turbo Stream Templates

### File naming convention

```
app/views/posts/create.turbo_stream.erb
app/views/posts/update.turbo_stream.erb
app/views/posts/destroy.turbo_stream.erb
```

Rails automatically renders `{action}.turbo_stream.erb` when the controller responds with `format.turbo_stream`.

### Multi-action template example

```erb
<%# app/views/comments/create.turbo_stream.erb %>

<%# 1. Add the new comment to the list %>
<%= turbo_stream.append "comments_for_#{@comment.post_id}",
    partial: "comments/comment",
    locals: { comment: @comment } %>

<%# 2. Update the comment count %>
<%= turbo_stream.update "comment_count_#{@comment.post_id}",
    html: pluralize(@comment.post.comments.count, "comment") %>

<%# 3. Clear the form %>
<%= turbo_stream.replace "new_comment_form" do %>
  <%= render "comments/form", comment: Comment.new(post: @comment.post) %>
<% end %>
```

### Stream with block syntax

```erb
<%= turbo_stream.update "sidebar" do %>
  <h3>Updated Content</h3>
  <p>This can contain arbitrary HTML.</p>
  <%= render partial: "shared/widget" %>
<% end %>
```
