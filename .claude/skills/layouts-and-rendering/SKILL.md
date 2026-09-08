---
name: layouts-and-rendering
description: Expert guidance for Rails view rendering, layouts, partials, and content composition. Use when rendering templates, choosing between render and redirect_to, creating or using partials, working with layouts, using content_for/yield/provide, rendering collections, streaming responses, or handling Turbo-aware status codes. Covers render vs redirect (agents confuse these!), partial locals (never instance variables!), layout selection, conditional rendering, nested layouts, and collection rendering.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails *), Bash(bundle exec rails *)
---

# Rails Layouts & Rendering Expert

Render the right thing, the right way, with the right status code.

## The #1 Rule: Partials Use Locals, Not Instance Variables

```ruby
# ❌ WRONG — implicit coupling, untestable, will break
<%= render "product" %>
# _product.html.erb uses @product

# ✅ RIGHT — explicit, testable, reusable
<%= render partial: "product", locals: { product: @product } %>
# or shorthand:
<%= render "product", product: @product %>
```

**Every partial gets its data through locals.** No exceptions. Instance variables in partials create invisible coupling between controllers and views that breaks when partials are reused.

## The #2 Rule: render vs redirect_to

These do fundamentally different things. Getting this wrong is the most common agent mistake.

| | `render` | `redirect_to` |
|---|---|---|
| **What it does** | Renders a template in the CURRENT request | Sends HTTP 302, browser makes NEW request |
| **Instance variables** | Available (same request) | Gone (new request) |
| **URL in browser** | Stays the same | Changes to new URL |
| **Use when** | Showing errors, displaying content | After successful mutations |
| **HTTP round trips** | 0 (same request) | 1 (browser → server again) |

```ruby
def create
  @post = Post.new(post_params)
  if @post.save
    redirect_to @post              # ← Success: redirect (browser gets new URL)
  else
    render :new, status: :unprocessable_entity  # ← Failure: render (keep form data)
  end
end
```

**Critical:** `render :action_name` does NOT run that action's code. It only uses the template. If `index.html.erb` needs `@posts`, rendering `:index` from `show` won't set `@posts` — you must set it yourself or redirect instead.

## When To Use This Skill

- Choosing between render, redirect_to, and head
- Setting up layouts (per-controller, per-action, conditional, nested)
- Creating partials with proper local variables
- Using content_for / yield for multi-section layouts
- Rendering collections efficiently
- Handling Turbo/Hotwire status codes correctly
- Streaming responses
- Rendering JSON/XML/plain text/HTML from controllers

## Instructions

### Step 1: Choose the Right Response Type

```ruby
# Full HTML response (most common)
render :show                          # Convention: renders show.html.erb
render "products/show"                # Cross-controller template
render partial: "form", locals: { post: @post }

# Data responses
render json: @product                 # Auto-calls .to_json
render xml: @product                  # Auto-calls .to_xml
render plain: "OK"                    # text/plain, no layout
render html: helpers.tag.strong("Hi") # HTML fragment

# Redirect (after successful mutation)
redirect_to @product                  # 302 by default
redirect_to products_path, status: :see_other  # 303 for Turbo
redirect_back fallback_location: root_path

# Headers only
head :no_content                      # 204, for API delete
head :created, location: photo_url(@photo)
```

### Step 2: Get Status Codes Right (Turbo-Critical)

**With Turbo Drive (Rails 7+), status codes determine behavior:**

```ruby
# After failed validation — MUST be 422 for Turbo to replace the page
render :new, status: :unprocessable_entity    # 422

# After successful redirect — MUST be 303 for Turbo
redirect_to @post, status: :see_other         # 303

# Turbo Stream responses
render turbo_stream: turbo_stream.remove(@post)  # 200 OK
```

| Scenario | Status | Why |
|----------|--------|-----|
| Validation failed, re-render form | `422 :unprocessable_entity` | Turbo replaces page content |
| Successful create/update | `303 :see_other` (redirect) | Turbo follows redirect with GET |
| Destroy success | `303 :see_other` (redirect) | Same reason |
| API success | `200 :ok` or `201 :created` | Standard API convention |
| Not found | `404 :not_found` | Standard |

**If you use `redirect_to` without `status: :see_other` in a Turbo app, Turbo may not follow the redirect correctly after form submissions.**

### Step 3: Layouts

#### How Rails Finds Layouts

1. Per-action: `render layout: "special"` in the action
2. Per-controller: `layout "admin"` declaration
3. Convention: `app/views/layouts/photos.html.erb` for `PhotosController`
4. Fallback: `app/views/layouts/application.html.erb`

```ruby
# Per-controller layout
class AdminController < ApplicationController
  layout "admin"
end

# Conditional layout
class ProductsController < ApplicationController
  layout "product", except: [:index, :rss]
end

# Runtime layout selection
class ProductsController < ApplicationController
  layout :choose_layout

  private

  def choose_layout
    current_user&.admin? ? "admin" : "application"
  end
end

# Per-action override
def special
  render layout: "minimal"
end

# No layout at all
def api_endpoint
  render json: @data, layout: false
end
```

#### Layout Inheritance

Layouts cascade down the controller hierarchy:

```ruby
class ApplicationController < ActionController::Base
  layout "main"       # All controllers use "main"
end

class ArticlesController < ApplicationController
  # Inherits "main" layout
end

class SpecialArticlesController < ArticlesController
  layout "special"    # Overrides to "special"
end

class ApiController < ApplicationController
  layout false        # No layout at all
end
```

#### Nested Layouts (Sub-Templates)

Use `content_for` + `render template:` to extend a parent layout:

```erb
<%# app/views/layouts/admin.html.erb — extends application layout %>
<% content_for :head do %>
  <%= stylesheet_link_tag "admin" %>
<% end %>

<% content_for :content do %>
  <div class="admin-sidebar"><%= yield :sidebar %></div>
  <div class="admin-main"><%= yield %></div>
<% end %>

<%= render template: "layouts/application" %>
```

The application layout needs to support this:
```erb
<%# app/views/layouts/application.html.erb %>
<html>
<head><%= yield :head %></head>
<body>
  <%= content_for?(:content) ? yield(:content) : yield %>
</body>
</html>
```

### Step 4: Partials — Always Use Locals

#### Basic Partial Rendering

```ruby
# Explicit (preferred when passing locals)
<%= render partial: "form", locals: { post: @post } %>

# Shorthand (works for simple cases)
<%= render "form", post: @post %>

# Model shorthand — renders _post.html.erb with local `post`
<%= render @post %>

# Cross-directory partial
<%= render "shared/navbar", current_user: @user %>
```

#### The Partial Contract

Every partial should document its expected locals at the top:

```erb
<%# app/views/posts/_post.html.erb %>
<%# locals: (post:, show_actions: true) %>
<article>
  <h2><%= post.title %></h2>
  <p><%= post.body %></p>
  <% if show_actions %>
    <%= link_to "Edit", edit_post_path(post) %>
  <% end %>
</article>
```

The magic comment `<%# locals: (post:, show_actions: true) %>` (Rails 7.1+) does two things:
1. Documents expected locals
2. Raises errors if required locals are missing

#### Optional Locals (Before Rails 7.1)

```erb
<%# Check with local_assigns for optional params %>
<% if local_assigns[:full] %>
  <%= simple_format article.body %>
<% else %>
  <%= truncate article.body %>
<% end %>
```

### Step 5: Collection Rendering

**Always use collection rendering for lists.** It's faster (single render call) and cleaner.

```erb
# ❌ SLOW — N render calls
<% @products.each do |product| %>
  <%= render partial: "product", locals: { product: product } %>
<% end %>

# ✅ FAST — single render call, Rails optimizes internally
<%= render partial: "product", collection: @products %>

# ✅ FASTEST shorthand — Rails infers partial name from model
<%= render @products %>

# Empty collection handling
<%= render(@products) || "No products yet." %>
```

#### Collection Features

```erb
# Custom local variable name
<%= render partial: "product", collection: @products, as: :item %>

# Counter variable (0-indexed) — available as product_counter
# Inside _product.html.erb: product_counter gives 0, 1, 2...

# Spacer template — rendered between items
<%= render partial: @products, spacer_template: "product_divider" %>

# Extra locals passed to every item
<%= render partial: "product", collection: @products,
           locals: { show_price: true } %>

# Layout for each item
<%= render partial: "product", collection: @products, layout: "card" %>
```

#### Heterogeneous Collections

```erb
# Rails picks the right partial based on model class
<%= render [customer1, employee1, customer2] %>
# Renders customers/_customer.html.erb and employees/_employee.html.erb
```

### Step 6: content_for and yield

Use `content_for` to inject content into named regions of your layout.

```erb
<%# Layout: app/views/layouts/application.html.erb %>
<html>
<head>
  <title><%= yield :title %></title>
  <%= yield :head %>
</head>
<body>
  <%= yield :breadcrumbs %>
  <%= yield %>  <%# Main content (unnamed yield) %>
</body>
</html>

<%# View: app/views/posts/show.html.erb %>
<% content_for :title, @post.title %>

<% content_for :head do %>
  <%= tag.meta name: "description", content: @post.excerpt %>
<% end %>

<% content_for :breadcrumbs do %>
  <nav>Posts > <%= @post.title %></nav>
<% end %>

<article>
  <h1><%= @post.title %></h1>
  <%= simple_format @post.body %>
</article>
```

#### content_for? — Conditional Sections

```erb
<%# Only render sidebar wrapper if content exists %>
<% if content_for?(:sidebar) %>
  <aside><%= yield :sidebar %></aside>
<% end %>
```

#### provide vs content_for

```ruby
provide :title, "My Page"       # Sets once, stops looking (streaming-friendly)
content_for :title, "My Page"   # Appends, can be called multiple times
```

Use `provide` for single values (page title). Use `content_for` for accumulated content (multiple script tags).

### Step 7: Avoid Double Render Errors

Rails raises `AbstractController::DoubleRenderError` if you render/redirect twice.

```ruby
# ❌ BUG — both render calls execute
def show
  @book = Book.find(params[:id])
  if @book.special?
    render :special_show
  end
  render :regular_show  # Always runs!
end

# ✅ FIX — return after render
def show
  @book = Book.find(params[:id])
  if @book.special?
    return render :special_show
  end
  render :regular_show
end

# ✅ ALSO FINE — implicit render for else case
def show
  @book = Book.find(params[:id])
  render :special_show if @book.special?
  # Implicit render of :show if special? is false
end
```

**The `return render` pattern is the cleanest for conditional rendering.**

### Step 8: Template Inheritance

Controllers inherit template lookup from parent controllers:

```ruby
# Lookup order for Admin::ProductsController#index:
# 1. app/views/admin/products/index.html.erb
# 2. app/views/admin/index.html.erb
# 3. app/views/application/index.html.erb
```

This makes `app/views/application/` ideal for shared partials:

```erb
<%# app/views/application/_empty_list.html.erb %>
<p>No items yet.</p>

<%# Usable from any controller's view: %>
<%= render(@products) || render("empty_list") %>
```

## Quick Reference

### render Cheat Sheet

```ruby
# Templates
render :edit                          # Same controller template
render "edit"                         # Same (string)
render "products/show"                # Other controller template
render template: "products/show"      # Explicit

# Data
render json: @product                 # JSON
render xml: @product                  # XML
render plain: "OK"                    # Plain text
render html: "<b>Hi</b>".html_safe    # HTML fragment
render body: "raw"                    # Raw body, no content type
render js: "alert('hi')"             # JavaScript

# Files
render file: Rails.root.join("public/404.html"), layout: false
render inline: "<%= 1 + 1 %>"        # Don't use this

# Options (combinable)
render :edit, status: :unprocessable_entity
render :show, layout: "minimal"
render :show, layout: false
render :show, content_type: "application/rss"
render :show, formats: [:json]
render :show, variants: [:mobile]
```

### redirect_to Cheat Sheet

```ruby
redirect_to @post                            # record → show path
redirect_to posts_path                       # named route
redirect_to "https://example.com"            # URL
redirect_to action: :index                   # hash
redirect_back fallback_location: root_path   # back button

# With status (important for Turbo!)
redirect_to @post, status: :see_other        # 303
redirect_to posts_path, status: 301          # permanent

# With flash
redirect_to @post, notice: "Created!"
redirect_to @post, alert: "Problem!"
```

### Standard CRUD Controller Pattern (Turbo-Aware)

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: "Created!", status: :see_other
    else
      render :new, status: :unprocessable_entity
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

## Anti-Patterns

1. **Instance variables in partials** — Always pass locals explicitly
2. **`render` thinking it's `redirect_to`** — render doesn't change URL or re-run actions
3. **Missing `status: :unprocessable_entity`** — Turbo won't replace page without 422
4. **Missing `status: :see_other`** — Turbo may not follow redirects after POST/PUT/DELETE
5. **`render inline:`** — Defeats MVC. Use a template
6. **Double render without return** — Use `return render :action` pattern
7. **`redirect_to` for form errors** — Redirect loses `@record.errors`; render instead
8. **Forgetting `fallback_location` with `redirect_back`** — Will raise if no referer
9. **`render file:` with user input** — Path traversal vulnerability
10. **`content_for` when `provide` suffices** — `provide` is streaming-friendly

---

See `reference.md` in this skill directory for detailed rendering patterns, layout examples, and edge cases.
