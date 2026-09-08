# Layouts & Rendering — Reference

Detailed patterns, edge cases, and examples for Rails view rendering.

## Table of Contents

- [Rendering Deep Dive](#rendering-deep-dive)
- [Layout Patterns](#layout-patterns)
- [Partial Patterns](#partial-patterns)
- [Collection Rendering](#collection-rendering)
- [content_for / yield / provide](#content_for--yield--provide)
- [Turbo / Hotwire Integration](#turbo--hotwire-integration)
- [Streaming](#streaming)
- [JSON / API Rendering](#json--api-rendering)
- [Edge Cases & Gotchas](#edge-cases--gotchas)
- [Template Inheritance](#template-inheritance)
- [View Components & Renderables](#view-components--renderables)

---

## Rendering Deep Dive

### Convention Over Configuration

Rails auto-renders the template matching the action name:

```ruby
class BooksController < ApplicationController
  def index
    @books = Book.all
    # Implicitly renders app/views/books/index.html.erb
  end
end
```

No `render` call needed. Rails checks if a render/redirect already happened; if not, it renders `action_name.html.erb`.

### All render Variants

```ruby
# === Template rendering ===

# Same controller (all equivalent):
render :edit
render action: :edit
render "edit"
render action: "edit"
render "books/edit"          # Cross-controller (note: slash means different controller)
render template: "books/edit"  # Explicit form

# === Data rendering ===

render json: @product                    # Calls .to_json automatically
render json: @product, status: :created  # With status
render json: { error: "not found" }, status: :not_found

render xml: @product                     # Calls .to_xml automatically

render plain: "OK"                       # text/plain
render plain: "OK", layout: true         # With layout (needs .text.erb layout)

render html: helpers.tag.strong("Hi")    # Safe HTML fragment
render html: "<b>Hi</b>".html_safe       # Manually marked safe

render js: "alert('done')"              # text/javascript

render body: "raw bytes"                 # No content-type set
render body: nil, status: :no_content    # 204 with empty body

# === File rendering ===

render file: Rails.root.join("public/404.html"), layout: false
# WARNING: Never use user input in file path — path traversal attack

# === Inline rendering (don't use) ===
render inline: "<%= @name %>"            # ERB in controller — bad practice

# === Renderable objects ===
render MyComponent.new(name: "World")    # Anything responding to #render_in
render renderable: MyComponent.new       # Explicit form
```

### render_to_string

Same options as `render`, returns a string instead of setting the response:

```ruby
html = render_to_string partial: "invoice", locals: { invoice: @invoice }
InvoiceMailer.send_invoice(@user, html).deliver_later
```

### The :formats and :variants Options

```ruby
# Force a specific format
render :index, formats: :json          # Renders index.json.jbuilder
render :index, formats: [:json, :xml]  # Tries json first, then xml

# Variant rendering (mobile/desktop)
request.variant = :mobile              # Set in controller

# Then Rails looks for:
# app/views/posts/index.html+mobile.erb
# app/views/posts/index.html.erb (fallback)

# Or force in render call:
render :index, variants: [:mobile, :desktop]
```

---

## Layout Patterns

### Layout Lookup Order

1. `render layout: "specific"` — per-action override
2. `layout "name"` — controller declaration
3. `app/views/layouts/controller_name.html.erb` — convention match
4. `app/views/layouts/application.html.erb` — global fallback

### Controller Layout Declarations

```ruby
# Static layout name
class AdminController < ApplicationController
  layout "admin"
end

# Symbol — calls method at render time
class ProductsController < ApplicationController
  layout :resolve_layout

  private

  def resolve_layout
    action_name == "index" ? "products_index" : "products"
  end
end

# Proc — evaluated with controller instance
class ProductsController < ApplicationController
  layout ->(controller) { controller.request.xhr? ? "modal" : "application" }
end

# Conditional — only/except
class ProductsController < ApplicationController
  layout "product", except: [:index, :rss]
end

# Disable layout entirely
class ApiController < ApplicationController
  layout false
end
```

### Layout Inheritance Chain

```ruby
class ApplicationController < ActionController::Base
  layout "main"
end

class ArticlesController < ApplicationController
  # Uses "main"
end

class SpecialArticlesController < ArticlesController
  layout "special"  # Overrides to "special"
end

class OldArticlesController < SpecialArticlesController
  layout false  # No layout

  def index
    render layout: "old"  # Per-action override wins
  end
end
```

Result:
- `ArticlesController#index` → `main` layout
- `SpecialArticlesController#index` → `special` layout
- `OldArticlesController#show` → no layout
- `OldArticlesController#index` → `old` layout

### Nested Layouts (Sub-Templates)

Build layout hierarchies with `content_for` + `render template:`:

```erb
<%# app/views/layouts/application.html.erb — BASE layout %>
<html>
<head>
  <title><%= yield :title %></title>
  <%= stylesheet_link_tag "application" %>
  <%= yield :head %>
</head>
<body>
  <div id="top_menu">Top menu</div>
  <div id="menu">Menu</div>
  <div id="content">
    <%= content_for?(:content) ? yield(:content) : yield %>
  </div>
</body>
</html>
```

```erb
<%# app/views/layouts/admin.html.erb — EXTENDS application %>
<% content_for :head do %>
  <%= stylesheet_link_tag "admin" %>
<% end %>

<% content_for :content do %>
  <div class="admin-sidebar"><%= yield :sidebar %></div>
  <div class="admin-main">
    <%= content_for?(:admin_content) ? yield(:admin_content) : yield %>
  </div>
<% end %>

<%= render template: "layouts/application" %>
```

The key pattern: `content_for?(:name) ? yield(:name) : yield` allows further nesting.

### Layout for Partials

Partials can have their own layouts (note: underscore-prefixed, same directory):

```erb
<%= render partial: "post", layout: "card", locals: { post: @post } %>
```

This renders `_post.html.erb` wrapped in `_card.html.erb` (both in same directory):

```erb
<%# _card.html.erb %>
<div class="card shadow-md p-4">
  <%= yield %>
</div>
```

---

## Partial Patterns

### The Locals Contract

**Always use locals. Never rely on instance variables in partials.**

```erb
<%# ✅ GOOD — explicit contract %>
<%= render partial: "user_card", locals: { user: @user, show_email: false } %>

<%# ✅ GOOD — shorthand %>
<%= render "user_card", user: @user, show_email: false %>

<%# ❌ BAD — implicit coupling to controller %>
<%= render "user_card" %>
<%# _user_card.html.erb uses @user — breaks when reused %>
```

### Strict Locals (Rails 7.1+)

Define expected locals with a magic comment:

```erb
<%# app/views/posts/_post.html.erb %>
<%# locals: (post:, show_actions: true, wrapper_class: "post-item") %>
<article class="<%= wrapper_class %>">
  <h2><%= post.title %></h2>
  <%= simple_format post.body %>
  <% if show_actions %>
    <div class="actions">
      <%= link_to "Edit", edit_post_path(post) %>
      <%= link_to "Delete", post_path(post), data: { turbo_method: :delete } %>
    </div>
  <% end %>
</article>
```

- `post:` — required (no default)
- `show_actions: true` — optional with default
- Missing required locals raise `ActionView::Template::Error`

### local_assigns (Pre-7.1 or Complex Cases)

```erb
<%# Optional local with fallback %>
<% title = local_assigns.fetch(:title, "Default Title") %>
<h1><%= title %></h1>

<%# Check if local was passed at all %>
<% if local_assigns.key?(:subtitle) %>
  <h2><%= subtitle %></h2>
<% end %>
```

### The :object Shorthand

```erb
<%# Pass @customer as the `customer` local %>
<%= render partial: "customer", object: @new_customer %>
<%# Inside _customer.html.erb, `customer` refers to @new_customer %>

<%# Model instance shorthand (Rails infers partial + local name) %>
<%= render @customer %>
<%# Renders customers/_customer.html.erb with customer: @customer %>
```

### Cross-Directory Partials

```erb
<%# Renders app/views/shared/_sidebar.html.erb %>
<%= render "shared/sidebar", links: @nav_links %>

<%# Renders app/views/application/_flash.html.erb (template inheritance) %>
<%= render "flash", messages: flash %>
```

### Partials with Blocks (Yielding Partials)

Partials can yield to a block:

```erb
<%# app/views/application/_card.html.erb %>
<div class="card">
  <div class="card-header"><%= title %></div>
  <div class="card-body"><%= yield %></div>
</div>

<%# Usage: %>
<%= render "card", title: "My Card" do %>
  <p>This content goes in the card body.</p>
<% end %>
```

More sophisticated — yield with a value:

```erb
<%# app/views/application/_search_filters.html.erb %>
<%= form_with model: search, url: search_path do |form| %>
  <fieldset>
    <%= yield form %>
  </fieldset>
  <p><%= form.submit "Search" %></p>
<% end %>

<%# Usage: %>
<%= render "search_filters", search: @q do |form| %>
  <p>Name: <%= form.text_field :name_contains %></p>
<% end %>
```

---

## Collection Rendering

### Basic Collection

```erb
<%# Full form %>
<%= render partial: "product", collection: @products %>

<%# Shorthand — Rails infers partial from model class %>
<%= render @products %>
```

Inside `_product.html.erb`, the local `product` is automatically set to each item.

### Custom Local Variable Name

```erb
<%= render partial: "product", collection: @products, as: :item %>
<%# Inside partial: `item` instead of `product` %>
```

### Counter Variable

Automatically available as `{partial_name}_counter` (0-indexed):

```erb
<%# _product.html.erb %>
<tr class="<%= product_counter.even? ? 'bg-white' : 'bg-gray-50' %>">
  <td><%= product_counter + 1 %>.</td>
  <td><%= product.name %></td>
</tr>
```

With `as: :item`, the counter becomes `item_counter`.

### Spacer Templates

Render a divider between items:

```erb
<%= render partial: @products, spacer_template: "product_ruler" %>
<%# _product_ruler.html.erb renders between each pair %>
```

```erb
<%# _product_ruler.html.erb %>
<hr class="my-4 border-gray-200">
```

### Empty Collection Handling

```erb
<%# render returns nil for empty collections %>
<%= render(@products) || render("empty_state", message: "No products yet.") %>

<%# Simple string fallback %>
<%= render(@products) || "No products available." %>

<%# Content tag fallback %>
<%= render(@products) || content_tag(:p, "Nothing here yet.", class: "text-muted") %>
```

### Extra Locals for All Items

```erb
<%= render partial: "product", collection: @products,
           locals: { show_price: current_user.admin? } %>
```

### Collection Layout

Each item rendered inside a layout:

```erb
<%= render partial: "product", collection: @products, layout: "product_wrapper" %>
```

```erb
<%# _product_wrapper.html.erb %>
<div class="product-card" id="product-<%= product.id %>">
  <%= yield %>
</div>
```

The layout has access to `product` and `product_counter`.

### Heterogeneous Collections

```erb
<%# Mixed model types — Rails picks the right partial %>
<%= render [customer1, employee1, customer2] %>
# Renders customers/_customer.html.erb for Customer instances
# Renders employees/_employee.html.erb for Employee instances
```

### Cached Collection Rendering

```erb
<%# Cache each partial fragment individually %>
<%= render partial: "product", collection: @products, cached: true %>
```

Rails caches each rendered partial keyed by the record's cache key. Dramatically faster for collections that rarely change.

For custom cache keys:

```erb
<%= render partial: "product", collection: @products,
           cached: ->(product) { [product, current_user.locale] } %>
```

---

## content_for / yield / provide

### yield — Named Regions in Layouts

```erb
<%# Layout %>
<html>
<head>
  <%= yield :head %>        <%# Named yield — for page-specific head content %>
</head>
<body>
  <%= yield :breadcrumbs %> <%# Named yield — for breadcrumbs %>
  <%= yield %>              <%# Unnamed yield — main page content %>
  <%= yield :footer_scripts %> <%# Named yield — for page-specific JS %>
</body>
</html>
```

### content_for — Inject Into Named Yields

```erb
<%# In a view: %>
<% content_for :head do %>
  <meta name="description" content="<%= @post.excerpt %>">
  <%= stylesheet_link_tag "posts" %>
<% end %>

<% content_for :breadcrumbs do %>
  <nav><%= link_to "Posts", posts_path %> > <%= @post.title %></nav>
<% end %>

<h1><%= @post.title %></h1>
<%= @post.body %>

<% content_for :footer_scripts do %>
  <script>initPostViewer()</script>
<% end %>
```

### content_for Appends

Multiple `content_for` calls with the same name **append**:

```erb
<% content_for :scripts do %>
  <script src="a.js"></script>
<% end %>

<% content_for :scripts do %>
  <script src="b.js"></script>
<% end %>

<%# yield :scripts outputs BOTH script tags %>
```

### provide — Set Once (No Append)

```erb
<% provide :title, "My Page" %>
<%# Second call does NOT append — first value wins %>
```

Use `provide` for:
- Page titles
- Single-value metadata
- Streaming-friendly content (flushes immediately)

Use `content_for` for:
- Accumulated content (multiple script/style tags)
- Content that builds up across partials

### content_for? — Conditional Rendering

```erb
<%# Only show sidebar if any view provided content for it %>
<% if content_for?(:sidebar) %>
  <aside class="sidebar">
    <%= yield :sidebar %>
  </aside>
<% end %>

<%# Fallback pattern %>
<title><%= content_for?(:title) ? yield(:title) : "My App" %></title>
```

### content_for in Partials

Partials can contribute to layout regions:

```erb
<%# _map_widget.html.erb %>
<div id="map"></div>

<% content_for :head do %>
  <script src="https://maps.googleapis.com/maps/api/js"></script>
<% end %>
```

---

## Turbo / Hotwire Integration

### Status Codes Are Critical

Turbo Drive intercepts form submissions and navigations. It uses HTTP status codes to decide behavior:

| Status | Turbo Behavior |
|--------|---------------|
| 200 | Replaces page body |
| 303 | Follows redirect with GET (correct for post-mutation) |
| 302 | **May cause issues** — Turbo may replay the original method |
| 422 | Replaces page body (shows validation errors) |
| 500 | Shows error page |

### Standard Turbo-Safe Controller

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: "Created!", status: :see_other  # 303!
    else
      render :new, status: :unprocessable_entity  # 422!
    end
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to @post, notice: "Updated!", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.destroy!
    redirect_to posts_path, notice: "Deleted!", status: :see_other
  end
end
```

### Turbo Stream Responses

```ruby
def create
  @post = Post.new(post_params)
  if @post.save
    respond_to do |format|
      format.turbo_stream  # Renders create.turbo_stream.erb
      format.html { redirect_to @post, status: :see_other }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", @post %>
<%= turbo_stream.update "post_count", Post.count %>
```

### Inline Turbo Stream

```ruby
render turbo_stream: turbo_stream.remove(@post)
render turbo_stream: [
  turbo_stream.remove(@post),
  turbo_stream.update("flash", partial: "shared/flash")
]
```

---

## Streaming

### Basic Streaming

```ruby
class ProductsController < ApplicationController
  include ActionController::Live

  def export
    response.headers["Content-Type"] = "text/csv"
    response.headers["Content-Disposition"] = 'attachment; filename="products.csv"'

    Product.find_each do |product|
      response.stream.write "#{product.id},#{product.name}\n"
    end
  ensure
    response.stream.close
  end
end
```

### Template Streaming

Flush the layout head before the body renders:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
    render stream: true  # Flushes layout <head> immediately
  end
end
```

**Note:** Template streaming requires `provide` instead of `content_for` for head content, because `content_for` waits until all content is collected.

---

## JSON / API Rendering

### Basic JSON

```ruby
render json: @product                          # Full object
render json: @product, only: [:id, :name]      # Whitelist
render json: @product, except: [:created_at]   # Blacklist
render json: @product, include: :reviews       # Include associations
render json: @products, each_serializer: ProductSerializer  # With serializer
```

### Custom JSON

```ruby
render json: {
  status: "success",
  data: @products.map { |p| { id: p.id, name: p.name } },
  meta: { total: @products.count }
}
```

### Jbuilder Templates

```ruby
# app/views/products/show.json.jbuilder
json.id @product.id
json.name @product.name
json.reviews @product.reviews do |review|
  json.id review.id
  json.body review.body
  json.rating review.rating
end
```

### respond_to

```ruby
def show
  @product = Product.find(params[:id])
  respond_to do |format|
    format.html            # Renders show.html.erb
    format.json            # Renders show.json.jbuilder
    format.xml { render xml: @product }
    format.csv { send_csv(@product) }
  end
end
```

---

## Edge Cases & Gotchas

### render Doesn't Run the Action

```ruby
# This is WRONG if index.html.erb needs @products:
def show
  @product = Product.find(params[:id])
  if @product.nil?
    render :index  # Template renders but @products is nil!
  end
end

# Fix: set up the data or redirect
def show
  @product = Product.find(params[:id])
  if @product.nil?
    @products = Product.all  # Must set up data for the template
    render :index
    # OR: redirect_to action: :index
  end
end
```

### redirect_to Doesn't Stop Execution

```ruby
# Code after redirect_to still runs!
def destroy
  redirect_to products_path
  @product.destroy!  # This still executes
  logger.info "Destroyed"  # This too
end

# Use return to stop:
def destroy
  redirect_to products_path
  return  # Stop here

  # or combine:
  return redirect_to products_path
end
```

### flash vs flash.now

```ruby
# redirect_to → use flash (persists to next request)
redirect_to @post, notice: "Saved!"
# Equivalent to:
flash[:notice] = "Saved!"
redirect_to @post

# render → use flash.now (current request only)
flash.now[:alert] = "Fix the errors below"
render :edit, status: :unprocessable_entity
# DON'T use flash[:alert] with render — it persists one request too many
```

### Layout for Non-HTML Formats

```ruby
# JSON/XML don't use layouts by default
render json: @product  # No layout

# Plain text doesn't use layout unless you ask:
render plain: "OK", layout: true
# Requires app/views/layouts/application.text.erb
```

### Implicit vs Explicit Rendering

```ruby
# Implicit (convention) — fine for simple cases
def show
  @product = Product.find(params[:id])
  # Renders show.html.erb automatically
end

# Explicit — use when you need options
def show
  @product = Product.find(params[:id])
  render :show, status: :ok  # Redundant but explicit
end

# No implicit render if you already rendered
def show
  @product = Product.find(params[:id])
  if @product.premium?
    render :premium_show  # Rendered — implicit render skipped
  end
  # No double render: implicit render detects prior render
end
```

### send_file vs render file

```ruby
# render file: renders file content as response body (within Rails)
render file: Rails.root.join("public/404.html"), layout: false

# send_file: streams file directly via web server (faster for downloads)
send_file Rails.root.join("storage/report.pdf"),
  type: "application/pdf",
  disposition: "attachment"
```

---

## Template Inheritance

### Lookup Chain

```ruby
class ApplicationController < ActionController::Base; end
class AdminController < ApplicationController; end
class Admin::ProductsController < AdminController; end
```

For `Admin::ProductsController#index`, Rails searches:
1. `app/views/admin/products/index.html.erb`
2. `app/views/admin/index.html.erb`
3. `app/views/application/index.html.erb`

Same for partials — `render "sidebar"` searches:
1. `app/views/admin/products/_sidebar.html.erb`
2. `app/views/admin/_sidebar.html.erb`
3. `app/views/application/_sidebar.html.erb`

### Shared Partials Location

Put truly shared partials in `app/views/application/`:

```erb
<%# app/views/application/_empty_state.html.erb %>
<%# locals: (message: "Nothing here yet.", icon: "inbox") %>
<div class="empty-state">
  <span class="icon"><%= icon %></span>
  <p><%= message %></p>
</div>
```

Accessible from any view without path prefix:
```erb
<%= render "empty_state", message: "No posts yet." %>
```

### Overriding Inherited Partials

```erb
<%# app/views/application/_header.html.erb — default header %>
<header>Default Header</header>

<%# app/views/admin/_header.html.erb — admin override %>
<header class="admin-header">Admin Header</header>

<%# In admin views, render "header" picks the admin version %>
```

---

## View Components & Renderables

### Custom Renderable Objects

Any object responding to `#render_in` and `#format` works with `render`:

```ruby
class AlertComponent
  def initialize(message:, type: :info)
    @message = message
    @type = type
  end

  def render_in(view_context)
    view_context.content_tag(:div, @message, class: "alert alert-#{@type}")
  end

  def format
    :html
  end
end

# In controller:
render AlertComponent.new(message: "Saved!", type: :success)

# In view:
<%= render AlertComponent.new(message: "Warning!", type: :warning) %>
```

### ViewComponent Gem Integration

```ruby
# app/components/alert_component.rb
class AlertComponent < ViewComponent::Base
  def initialize(message:, type: :info)
    @message = message
    @type = type
  end
end

# app/components/alert_component.html.erb
<div class="alert alert-<%= @type %>">
  <%= @message %>
</div>

# Usage:
<%= render AlertComponent.new(message: "Done!", type: :success) %>
```

---

## Debugging Rendering

### Finding Which Template Rendered

```ruby
# In development, check the HTML comments Rails adds
# Or add to ApplicationController:
after_action do
  Rails.logger.debug "Rendered: #{response.body[0..100]}..."
end
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ActionView::MissingTemplate` | Template file doesn't exist | Check path, format, and file extension |
| `AbstractController::DoubleRenderError` | Called render/redirect twice | Add `return` after first render/redirect |
| `ActionController::UnknownFormat` | No template for requested format | Add `respond_to` block or format-specific template |
| `ActionView::Template::Error: undefined local variable` | Missing local in partial | Pass all required locals, or use strict locals comment |
| `NoMethodError: undefined method for nil:NilClass` in view | Instance variable not set | Check you're in the right action, or render set up the variable |

### render_to_string for Debugging

```ruby
# Get rendered HTML without sending response
html = render_to_string(partial: "product", locals: { product: @product })
Rails.logger.debug html
```
