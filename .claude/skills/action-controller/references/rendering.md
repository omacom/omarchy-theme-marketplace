# Rendering, Redirects, and Flash Messages

Complete reference for rendering responses, redirect patterns, and flash message handling.

## Implicit rendering

If an action doesn't call `render` or `redirect_to`, Rails renders `app/views/<controller>/<action>.html.erb` automatically.

## Explicit render options

```ruby
render :new                              # template for action :new in current controller
render "articles/new"                    # cross-controller template
render template: "articles/new"          # explicit template option
render plain: "OK"                       # plain text
render html: "<h1>Hi</h1>".html_safe     # raw HTML
render json: @post                       # calls .to_json
render json: { error: "bad" }, status: 422
render xml: @post                        # calls .to_xml
render js: "alert('hi')"                 # JavaScript
render body: "raw"                       # raw body
render file: Rails.root.join("public/404.html"), layout: false
render inline: "<%= 'hi' %>"             # inline ERB (avoid in production code)
render nothing: true                     # deprecated — use head
```

## head — no body

```ruby
head :ok                  # 200
head :no_content          # 204
head :created, location: post_url(@post)
head :not_found           # 404
```

## Status codes

Use symbols, not numbers:

| Symbol | Code |
|--------|------|
| `:ok` | 200 |
| `:created` | 201 |
| `:no_content` | 204 |
| `:moved_permanently` | 301 |
| `:found` | 302 |
| `:see_other` | 303 |
| `:not_modified` | 304 |
| `:bad_request` | 400 |
| `:unauthorized` | 401 |
| `:forbidden` | 403 |
| `:not_found` | 404 |
| `:unprocessable_entity` | 422 |
| `:too_many_requests` | 429 |
| `:internal_server_error` | 500 |

## Layout control

```ruby
class AdminController < ApplicationController
  layout "admin"  # uses app/views/layouts/admin.html.erb
end

# Per-action layout
def show
  render layout: "minimal"
end

# Conditional layout
layout :determine_layout

private
  def determine_layout
    current_user&.admin? ? "admin" : "application"
  end
```

## respond_to for format negotiation

```ruby
def show
  @post = Post.find(params.expect(:id))
  respond_to do |format|
    format.html
    format.json { render json: @post }
    format.csv { send_data @post.to_csv, filename: "post.csv" }
    format.pdf { render pdf: generate_pdf(@post) }
  end
end
```

Register custom MIME types in `config/initializers/mime_types.rb`:

```ruby
Mime::Type.register "application/rtf", :rtf
```

## Variant-based rendering

```ruby
# Set variant in before_action
before_action :set_variant

def set_variant
  request.variant = :mobile if request.user_agent.match?(/Mobile|Android|iPhone/)
  request.variant = :tablet if request.user_agent.match?(/iPad/)
end

# In action
def show
  respond_to do |format|
    format.html do |html|
      html.mobile   # renders show.html+mobile.erb
      html.tablet   # renders show.html+tablet.erb
      html.none     # renders show.html.erb (default)
    end
  end
end
```

Template naming: `show.html+mobile.erb`, `show.html+tablet.erb`.

## Double render protection

```ruby
# ❌ This raises AbstractController::DoubleRenderError
def show
  render :one
  render :two
end

# ✅ Use early return
def show
  if condition
    render :special and return
  end
  render :normal
end

# ✅ Or use if/else
def show
  if condition
    render :special
  else
    render :normal
  end
end
```

A controller action can only render or redirect ONCE.

---

## Redirect Patterns

```ruby
redirect_to action: :show, id: 5
redirect_to @post                                  # polymorphic URL
redirect_to posts_url                              # named route
redirect_to "https://example.com"                  # external URL
redirect_to posts_path, notice: "Done!"            # with flash
redirect_to posts_path, alert: "Error!"
redirect_to posts_path, flash: { custom: "hi" }   # custom flash key
redirect_to posts_path, status: :see_other         # 303 for DELETE
redirect_to posts_path, allow_other_host: true      # allow external redirect

redirect_back fallback_location: root_path         # go back or fallback
redirect_back_or_to root_path                       # Rails 7.1+ shorthand
```

### After DELETE — always use :see_other

```ruby
def destroy
  @post.destroy!
  redirect_to posts_path, notice: "Deleted.", status: :see_other
end
```

Without `:see_other` (303), the browser may replay the DELETE request on redirect.

---

## Flash Message Patterns

### Types

```ruby
flash[:notice]  # success messages (green)
flash[:alert]   # error/warning messages (red)
flash[:custom]  # any custom key you want
```

### When to use flash vs flash.now

| Situation | Use | Why |
|-----------|-----|-----|
| Before `redirect_to` | `flash[:notice]` | Flash persists to next request |
| Before `render` | `flash.now[:error]` | No redirect = same request; regular flash would leak to NEXT request |
| Multiple redirects | `flash.keep` | Carry flash through an extra redirect |

### flash.keep

```ruby
def index
  flash.keep  # carries ALL flash values through this redirect
  redirect_to dashboard_path
end

# Or keep specific key
flash.keep(:notice)
```

### Layout display

```erb
<!-- app/views/layouts/application.html.erb -->
<% flash.each do |type, message| %>
  <div class="flash flash-<%= type %>">
    <%= message %>
  </div>
<% end %>
```
