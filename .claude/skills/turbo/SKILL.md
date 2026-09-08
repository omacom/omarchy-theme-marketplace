---
name: turbo
description: Expert guidance for building modern Rails UIs with Turbo (Drive, Frames, Streams). Use when implementing partial page updates, real-time broadcasts, turbo frames, turbo streams, hotwire patterns, turbo_frame_tag, turbo_stream responses, lazy loading frames, morphing, page refreshes, or any "turbo" related Rails feature. Covers Turbo Drive navigation, Turbo Frames for scoped updates, Turbo Streams for real-time HTML delivery, and Turbo 8 morphing.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate *), Bash(bin/rails server)
---

# Rails Turbo Expert

Build fast, modern Rails UIs with zero (or minimal) custom JavaScript using Turbo Drive, Frames, and Streams.

## Philosophy

**Core Principles:**
1. **HTML over the wire** — The server renders HTML. Turbo delivers it. No JSON APIs for UI.
2. **Progressive enhancement** — Turbo Drive works automatically. Frames and Streams layer on top.
3. **Server is the source of truth** — Business logic stays in Ruby. Turbo just moves HTML around.
4. **Minimal JavaScript** — If you're writing JS to update the DOM, you're probably doing it wrong. Use Turbo Streams.
5. **Composable primitives** — Drive, Frames, and Streams each solve one problem. Combine them.

**The Mental Model:**
```
Turbo Drive  →  Speeds up ALL navigation (automatic, zero config)
Turbo Frames →  Scopes updates to a REGION of the page (explicit, per-element)
Turbo Streams → Delivers TARGETED mutations to ANY element (server-pushed or response)
```

**Decision Tree:**
```
Need faster page loads?                    → Turbo Drive (already on)
Need to update PART of a page on click?    → Turbo Frame
Need to update MULTIPLE parts at once?     → Turbo Stream
Need real-time updates from other users?   → Turbo Stream + ActionCable broadcast
Need smooth page refresh without flicker?  → Turbo Morph (Rails 8+)
```

## When To Use This Skill

- Adding turbo_frame_tag to scope navigation/updates
- Returning turbo_stream responses from controller actions
- Setting up real-time broadcasts with ActionCable
- Implementing lazy-loaded content
- Building inline editing, tabbed interfaces, modals
- Configuring Turbo Drive behavior (disabling for specific links/forms)
- Using Turbo 8 morphing and page refreshes

## Instructions

### Step 1: Understand What's Already There

Turbo Drive is **on by default** in every Rails 7+ app. You don't install it. You don't configure it. Every link click and form submission already goes through Turbo Drive.

**Check the app has turbo-rails:**
```bash
# Should already be in Gemfile
grep "turbo-rails" Gemfile

# JavaScript import should exist
rg "import.*turbo" app/javascript/
```

If missing (unlikely in Rails 7+):
```bash
bundle add turbo-rails
bin/rails turbo:install
```

### Step 2: Turbo Drive — Know When to Opt Out

Turbo Drive intercepts every `<a>` click and `<form>` submit, fetches via AJAX, and swaps the `<body>`. This is automatic. You only intervene to **disable** it.

```erb
<%# Disable for a specific link or form %>
<%= link_to "External Site", "https://example.com", data: { turbo: false } %>
<%= form_with model: @upload, data: { turbo: false } do |f| %>

<%# Disable for a whole section %>
<div data-turbo="false">...</div>
```

**Common opt-out scenarios:** file uploads (without Active Storage direct upload), external links, OAuth/SSO redirects, file downloads, payment forms (Stripe).

**Non-GET link methods — prefer `button_to` over `link_to` with `turbo_method`:**
```erb
<%# Acceptable %>
<%= link_to "Delete", post_path(@post), data: { turbo_method: :delete, turbo_confirm: "Sure?" } %>

<%# Better — more accessible and semantic %>
<%= button_to "Delete", post_path(@post), method: :delete,
    form: { data: { turbo_confirm: "Are you sure?" } } %>
```

### Step 3: Turbo Frames — Scoped Page Updates

Turbo Frames are the workhorse. They scope navigation to a **region** of the page. When a link or form inside a frame is clicked, only that frame updates.

**⚠️ THE #1 AGENT MISTAKE: Forgetting to wrap BOTH sides in matching turbo_frame_tag.**

The frame on the current page AND the response page must have a `<turbo-frame>` with the **same ID**. If they don't match, you get a Content Missing error.

**Basic Frame Pattern:**

```erb
<%# index.html.erb — the page with the frame %>
<%= turbo_frame_tag "post_#{@post.id}" do %>
  <h2><%= @post.title %></h2>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>

<%# edit.html.erb — the response MUST have matching frame %>
<%= turbo_frame_tag "post_#{@post.id}" do %>
  <%= render "form", post: @post %>
<% end %>
```

**Use `dom_id` for consistent IDs:**
```erb
<%= turbo_frame_tag dom_id(@post) do %>
  <%# dom_id(@post) produces "post_123" %>
<% end %>
```

**Lazy-loaded frames (load content after page render):**
```erb
<%= turbo_frame_tag "comments", src: post_comments_path(@post), loading: :lazy do %>
  <p>Loading comments...</p>
<% end %>
```

The `src` URL is fetched automatically. The `loading: :lazy` defers until the frame is visible (Intersection Observer). Without `:lazy`, it loads immediately after page load.

**⚠️ AGENT GOTCHA: The lazy-loaded endpoint must return a page with a matching turbo_frame_tag.** The controller doesn't need to know it's a frame — it renders normally, and Turbo extracts the matching frame.

**Breaking out of a frame (target the whole page):**
```erb
<%= turbo_frame_tag dom_id(@post) do %>
  <%# This link stays in the frame %>
  <%= link_to "Edit", edit_post_path(@post) %>
  
  <%# This link breaks out and navigates the full page %>
  <%= link_to "Show Full Page", post_path(@post), data: { turbo_frame: "_top" } %>
<% end %>
```

**Target a DIFFERENT frame:**
```erb
<%= turbo_frame_tag "sidebar" do %>
  <%= link_to "Load Details", post_path(@post), data: { turbo_frame: "main_content" } %>
<% end %>

<%# This frame will be updated instead %>
<%= turbo_frame_tag "main_content" do %>
  <p>Select a post from the sidebar</p>
<% end %>
```

**Frame with custom `target` attribute (all links inside target another frame):**
```erb
<%= turbo_frame_tag "nav", target: "main_content" do %>
  <%# ALL links here update "main_content" frame instead %>
  <%= link_to "Posts", posts_path %>
  <%= link_to "Users", users_path %>
<% end %>
```

### Step 4: Turbo Streams — Targeted DOM Mutations

Turbo Streams are surgical. They say "take this HTML and append/replace/remove it at this DOM target." They work in two contexts:

1. **HTTP responses** — returned from form submissions (POST/PUT/PATCH/DELETE)
2. **WebSocket broadcasts** — pushed to all connected users via ActionCable

**The 7 stream actions:**

| Action | What it does |
|--------|-------------|
| `append` | Add HTML to END of target's children |
| `prepend` | Add HTML to START of target's children |
| `replace` | Replace the ENTIRE target element |
| `update` | Replace the INNER HTML of target |
| `remove` | Remove the target element |
| `before` | Insert HTML BEFORE the target |
| `after` | Insert HTML AFTER the target |

**⚠️ CRITICAL DISTINCTION: `replace` vs `update`**
- `replace` — removes the target element itself and puts new HTML in its place
- `update` — keeps the target element, replaces its children

```erb
<%# replace: <div id="post_1"> is GONE, replaced entirely %>
<%= turbo_stream.replace dom_id(@post), partial: "posts/post", locals: { post: @post } %>

<%# update: <div id="post_1"> stays, its contents are swapped %>
<%= turbo_stream.update dom_id(@post), partial: "posts/post", locals: { post: @post } %>
```

**Responding with Turbo Streams from a controller:**

```ruby
# app/controllers/posts_controller.rb
def create
  @post = Post.new(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream  # Renders create.turbo_stream.erb
      format.html { redirect_to @post }
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

```erb
<%# app/views/posts/create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", partial: "posts/post", locals: { post: @post } %>
<%= turbo_stream.update "post_count", html: "#{Post.count} posts" %>
<%= turbo_stream.update "new_post_form" do %>
  <%= render "form", post: Post.new %>
<% end %>
```

**⚠️ AGENT GOTCHA: Turbo Stream responses ONLY work for non-GET requests.** GET requests use Turbo Drive or Frames. If you try to return a turbo_stream format from a GET, it won't work. Use a frame instead.

**Inline stream rendering (skip the template):**
```ruby
def destroy
  @post.destroy

  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@post)) }
    format.html { redirect_to posts_path }
  end
end
```

**Multiple stream actions inline:**
```ruby
format.turbo_stream do
  render turbo_stream: [
    turbo_stream.remove(dom_id(@post)),
    turbo_stream.update("post_count", html: "#{Post.count} posts")
  ]
end
```

### Step 5: Turbo Stream Broadcasts (Real-Time)

Broadcasts push Turbo Stream actions to all users subscribed to a channel via ActionCable. This is how you get "real-time" without writing any JavaScript.

**Setup the subscription in the view:**
```erb
<%# This creates an ActionCable subscription %>
<%= turbo_stream_from "posts" %>

<%# Scoped to a specific record %>
<%= turbo_stream_from @project %>

<%# Multiple stream names %>
<%= turbo_stream_from @project, "messages" %>
```

**Broadcast from the model:**
```ruby
class Post < ApplicationRecord
  # Broadcast AFTER commit (not after save — important for transactions)
  after_create_commit  { broadcast_append_to "posts" }
  after_update_commit  { broadcast_replace_to "posts" }
  after_destroy_commit { broadcast_remove_to "posts" }

  # Shorthand for all three:
  broadcasts_to ->(post) { "posts" }
  # Or if broadcasting to a parent:
  broadcasts_to :project
end
```

**Broadcast with a custom partial:**
```ruby
after_create_commit do
  broadcast_append_to "posts",
    target: "posts_list",
    partial: "posts/post_card",
    locals: { post: self }
end
```

**Broadcast from anywhere (controller, job, service):**
```ruby
Turbo::StreamsChannel.broadcast_append_to("posts", target: "posts_list",
  partial: "posts/post", locals: { post: @post })
Turbo::StreamsChannel.broadcast_remove_to("posts", target: dom_id(@post))
```

**⚠️ AGENT GOTCHA: Broadcasts render partials WITHOUT a request context.** This means no `current_user`, no `request`, no session. Design your partials to work without these, or pass needed data as locals.

### Step 6: Turbo 8 Morphing (Rails 8+)

Morphing is a page-refresh strategy that updates the DOM by **diffing** instead of replacing. It preserves form state, scroll position, and CSS transitions.

**Enable morphing for a page:**
```erb
<%# In the <head> of your layout or page %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

**What this does:**
- `method: :morph` — Diffs the new HTML against current DOM, applies minimal changes
- `scroll: :preserve` — Keeps scroll position after refresh

**Triggering a morph refresh from the server:**
```ruby
# In a broadcast:
after_update_commit do
  broadcast_refresh_to "posts"
end

# Shorthand:
broadcasts_refreshes
```

**When to use morph vs streams:**
- **Morph** — When you want to re-render the whole page but keep state (forms, scroll)
- **Streams** — When you want surgical, targeted updates to specific elements

**Mark elements to preserve across morphs:**
```erb
<div id="player" data-turbo-permanent>
  <%# This element survives morph refreshes intact %>
</div>
```

### Step 7: Forms in Turbo

Forms are where Turbo trips up agents the most. Key rules:

**Rule 1: Failed validations MUST return `422 Unprocessable Entity`.**
```ruby
def create
  @post = Post.new(post_params)
  if @post.save
    redirect_to @post
  else
    render :new, status: :unprocessable_entity  # ← CRITICAL
  end
end
```

Without `:unprocessable_entity`, Turbo won't render the error response. It'll follow the redirect status instead.

**Rule 2: Forms inside frames stay in frames.**
```erb
<%= turbo_frame_tag "new_post" do %>
  <%= form_with model: Post.new do |f| %>
    <%= f.text_field :title %>
    <%= f.submit "Create" %>
  <% end %>
<% end %>
```

The form submits via Turbo. The response must contain a matching `turbo_frame_tag "new_post"`. OR the controller responds with `turbo_stream` format to skip the frame requirement.

**Rule 3: Redirect after successful form submission.**
```ruby
# Turbo handles redirects correctly — it navigates the page
if @post.save
  redirect_to @post, notice: "Created!"  # Works fine with Turbo
end
```

**Rule 4: `form_with` uses Turbo by default in Rails 7+.** No `local: false` needed. To disable:
```erb
<%= form_with model: @post, data: { turbo: false } do |f| %>
```

### Step 8: Common Patterns

See the `references/` directory for detailed implementations:
- `references/frames.md` — Inline editing, tab navigation, lazy loading, modals, infinite scroll
- `references/streams.md` — Flash messages, live search, nested forms, counters, toasts, template conventions
- `references/broadcasting.md` — Scoped broadcasts, user-specific streams, background job patterns
- `references/morphing.md` — Turbo 8 morph refresh setup, when to use morph vs streams
- `references/testing.md` — Integration tests, system tests, broadcast assertions
- `references/edge-cases.md` — Stimulus integration, gotchas (file uploads, DELETE redirects, CSP, caching)

## Quick Reference

### Helper Methods

```erb
<%# Frames %>
<%= turbo_frame_tag "id" %>
<%= turbo_frame_tag dom_id(@record) %>
<%= turbo_frame_tag "id", src: path, loading: :lazy %>
<%= turbo_frame_tag "id", target: "_top" %>

<%# Stream subscription %>
<%= turbo_stream_from "channel_name" %>
<%= turbo_stream_from @record %>

<%# Stream actions (in .turbo_stream.erb templates) %>
<%= turbo_stream.append "target_id", partial: "partial" %>
<%= turbo_stream.prepend "target_id", partial: "partial" %>
<%= turbo_stream.replace dom_id(@record), partial: "partial" %>
<%= turbo_stream.update "target_id", html: "content" %>
<%= turbo_stream.remove dom_id(@record) %>
<%= turbo_stream.before dom_id(@record), partial: "partial" %>
<%= turbo_stream.after dom_id(@record), partial: "partial" %>

<%# Morphing (Rails 8+) %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

### Data Attributes

```erb
data-turbo="false"              <%# Disable Turbo for this element %>
data-turbo-method="delete"      <%# HTTP method for link %>
data-turbo-confirm="Sure?"      <%# Confirmation dialog %>
data-turbo-frame="_top"         <%# Break out of frame %>
data-turbo-frame="frame_id"     <%# Target specific frame %>
data-turbo-permanent             <%# Preserve across morphs %>
data-turbo-temporary             <%# Remove on morph refresh %>
data-turbo-action="advance"     <%# Push to browser history %>
data-turbo-action="replace"     <%# Replace browser history entry %>
```

### Model Broadcast Methods

```ruby
# Individual callbacks
after_create_commit  { broadcast_append_to "stream" }
after_update_commit  { broadcast_replace_to "stream" }
after_destroy_commit { broadcast_remove_to "stream" }

# All-in-one
broadcasts_to ->(record) { "stream_name" }
broadcasts_to :parent_association

# Morphing (Rails 8+)
broadcasts_refreshes
after_update_commit { broadcast_refresh_to "stream" }

# Manual broadcast from anywhere
Turbo::StreamsChannel.broadcast_append_to("stream", target: "id", partial: "path")
Turbo::StreamsChannel.broadcast_remove_to("stream", target: "id")
Turbo::StreamsChannel.broadcast_refresh_to("stream")
```

### Controller Response Pattern

```ruby
respond_to do |format|
  if @record.save
    format.turbo_stream  # renders action.turbo_stream.erb
    format.html { redirect_to @record }
  else
    format.html { render :new, status: :unprocessable_entity }
  end
end
```

## Common Agent Mistakes

1. **Missing matching frame IDs** — Both pages need `turbo_frame_tag` with same ID
2. **Returning 200 on validation failure** — Must be `status: :unprocessable_entity` (422)
3. **Turbo Stream on GET requests** — Streams only work on POST/PUT/PATCH/DELETE
4. **Using `current_user` in broadcast partials** — No request context in broadcasts
5. **Forgetting `turbo_stream_from` in the view** — Broadcasts need a subscription
6. **`replace` when you mean `update`** — `replace` removes the target element entirely
7. **Not using `dom_id`** — Manual IDs drift; `dom_id(@post)` is consistent
8. **Forgetting `after_*_commit`** — Use commit callbacks, not `after_save` for broadcasts
9. **No HTML fallback in `respond_to`** — Always include `format.html` for non-Turbo clients
10. **Lazy frame without placeholder content** — Show loading state inside the frame tag

## Anti-Patterns

1. **Building JSON APIs just for UI updates** — Use Turbo Streams instead
2. **Writing JavaScript to swap DOM content** — That's what Turbo does
3. **Nesting frames deeply** — Keep it to 1-2 levels; complexity explodes
4. **Broadcasting every model change** — Be selective; too many broadcasts = performance issues
5. **Giant turbo_stream.erb templates** — Keep stream responses focused; 1-3 actions per response
6. **Using Turbo Frames for things that need Streams** — If you need to update multiple unrelated areas, use Streams
7. **Skipping the HTML fallback** — Your app should work without Turbo (progressive enhancement)
