# Turbo Frames — Patterns & Examples

Detailed implementation patterns for Turbo Frames: inline editing, tabs, lazy loading, modals, and infinite scroll.

---

## Inline Editing with Frames

The classic Turbo Frame use case — click "Edit" to swap content in place.

### Show view (read mode)

```erb
<%# app/views/posts/_post.html.erb %>
<%= turbo_frame_tag dom_id(post) do %>
  <div class="post-card">
    <h3><%= post.title %></h3>
    <p><%= post.body %></p>
    <%= link_to "Edit", edit_post_path(post) %>
  </div>
<% end %>
```

### Edit view

```erb
<%# app/views/posts/edit.html.erb %>
<%= turbo_frame_tag dom_id(@post) do %>
  <%= render "form", post: @post %>
<% end %>

<%# Content outside the frame is ignored when loaded in a frame context %>
<p>This text only appears when visiting edit page directly.</p>
```

### Form partial

```erb
<%# app/views/posts/_form.html.erb %>
<%= form_with model: post do |f| %>
  <%= f.text_field :title %>
  <%= f.text_area :body %>
  <div>
    <%= f.submit %>
    <%= link_to "Cancel", post_path(post) %>
  </div>
<% end %>
```

### Controller

```ruby
def update
  @post = Post.find(params[:id])
  if @post.update(post_params)
    redirect_to @post  # Turbo Frame follows redirect, fetches show, extracts matching frame
  else
    render :edit, status: :unprocessable_entity
  end
end
```

**How it works:** The redirect loads the show page, Turbo finds the matching `turbo_frame_tag dom_id(@post)`, and swaps just that frame. The URL doesn't change (it's a frame navigation).

---

## Tab Navigation with Frames

Use a frame with `target` to build tabbed interfaces without JavaScript.

```erb
<%# Tabs navigation — targets the content frame %>
<%= turbo_frame_tag "tabs_nav", target: "tab_content" do %>
  <nav>
    <%= link_to "Details", project_details_path(@project),
        class: ("active" if current_page?(project_details_path(@project))) %>
    <%= link_to "Members", project_members_path(@project),
        class: ("active" if current_page?(project_members_path(@project))) %>
    <%= link_to "Settings", project_settings_path(@project),
        class: ("active" if current_page?(project_settings_path(@project))) %>
  </nav>
<% end %>

<%# Content area — updated by tab clicks %>
<%= turbo_frame_tag "tab_content" do %>
  <%= yield %>
<% end %>
```

Each tab endpoint renders its content inside a matching frame:

```erb
<%# app/views/projects/details.html.erb %>
<%= turbo_frame_tag "tab_content" do %>
  <h2>Project Details</h2>
  <%# ... details content ... %>
<% end %>
```

**Tip:** Add `data-turbo-action="advance"` to tab links to update the URL:
```erb
<%= link_to "Details", project_details_path(@project),
    data: { turbo_action: "advance" } %>
```

---

## Lazy-Loaded Content

Load expensive content after the page renders.

```erb
<%# Main page loads fast %>
<h1><%= @post.title %></h1>
<p><%= @post.body %></p>

<%# Comments load lazily (deferred until visible) %>
<%= turbo_frame_tag "comments",
    src: post_comments_path(@post),
    loading: :lazy do %>
  <div class="loading-spinner">
    Loading comments...
  </div>
<% end %>

<%# Sidebar stats load immediately after page (no :lazy) %>
<%= turbo_frame_tag "stats",
    src: post_stats_path(@post) do %>
  <p>Loading stats...</p>
<% end %>
```

### Controller for lazy endpoint

```ruby
class CommentsController < ApplicationController
  def index
    @post = Post.find(params[:post_id])
    @comments = @post.comments.includes(:author).order(created_at: :desc)
    # Renders index.html.erb — Turbo extracts the matching frame
  end
end
```

```erb
<%# app/views/comments/index.html.erb %>
<%= turbo_frame_tag "comments" do %>
  <% @comments.each do |comment| %>
    <%= render comment %>
  <% end %>
  <p><%= pluralize(@comments.count, "comment") %></p>
<% end %>
```

**Key point:** The controller doesn't know or care that it's being loaded in a frame. It renders a full page. Turbo extracts only the matching frame.

---

## Modal Dialogs

Use a dedicated frame for modals. The content loads from a different page.

```erb
<%# app/views/layouts/application.html.erb %>
<%= yield %>

<%# Empty frame for modals at the bottom of the layout %>
<%= turbo_frame_tag "modal" %>
```

```erb
<%# Any link can target the modal frame %>
<%= link_to "New Post", new_post_path, data: { turbo_frame: "modal" } %>
```

```erb
<%# app/views/posts/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="modal-overlay" data-controller="modal">
    <div class="modal-content">
      <h2>New Post</h2>
      <%= render "form", post: @post %>
    </div>
  </div>
<% end %>

<%# Fallback when visiting directly (no frame context) %>
<% content_for :main do %>
  <h1>New Post</h1>
  <%= render "form", post: @post %>
<% end %>
```

**Close the modal after successful save:**
```ruby
def create
  @post = Post.new(post_params)
  if @post.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.prepend("posts", partial: "posts/post", locals: { post: @post }),
          turbo_stream.update("modal", "")  # Clear the modal
        ]
      end
      format.html { redirect_to @post }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

---

## Infinite Scroll

Load more content when the user scrolls to the bottom.

```erb
<%# app/views/posts/index.html.erb %>
<div id="posts">
  <%= render @posts %>
</div>

<%= turbo_frame_tag "pagination", src: posts_path(page: @next_page), loading: :lazy do %>
  <p>Loading more...</p>
<% end if @next_page %>
```

```erb
<%# The paginated response APPENDS posts and includes the next pagination frame %>
<%= turbo_frame_tag "pagination" do %>
  <% @posts.each do |post| %>
    <%= render post %>
  <% end %>
  
  <% if @next_page %>
    <%= turbo_frame_tag "pagination", src: posts_path(page: @next_page), loading: :lazy do %>
      <p>Loading more...</p>
    <% end %>
  <% end %>
<% end %>
```

**Better approach using Turbo Streams:**
```ruby
# Controller
def index
  @posts = Post.page(params[:page]).per(20)
  @next_page = @posts.next_page

  respond_to do |format|
    format.html
    format.turbo_stream
  end
end
```

```erb
<%# app/views/posts/index.turbo_stream.erb %>
<% @posts.each do |post| %>
  <%= turbo_stream.append "posts", partial: "posts/post", locals: { post: post } %>
<% end %>

<% if @next_page %>
  <%= turbo_stream.replace "pagination" do %>
    <%= turbo_frame_tag "pagination", src: posts_path(page: @next_page, format: :turbo_stream), loading: :lazy do %>
      <p>Loading more...</p>
    <% end %>
  <% end %>
<% else %>
  <%= turbo_stream.remove "pagination" %>
<% end %>
```
