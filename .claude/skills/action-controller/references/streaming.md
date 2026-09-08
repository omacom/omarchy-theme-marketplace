# Streaming, Downloads, Request/Response, API Controllers

File downloads, live streaming, request/response objects, health checks, and API controller patterns.

## Streaming and Downloads

### send_data — generated content

```ruby
send_data content,
  filename: "report.csv",
  type: "text/csv",
  disposition: "attachment"  # "attachment" (download) or "inline" (display in browser)
```

### send_file — existing file on disk

```ruby
send_file path_to_file,
  filename: "download.pdf",
  type: "application/pdf",
  disposition: "attachment",
  stream: true,              # default: true, streams in 4KB chunks
  buffer_size: 4096          # chunk size
```

⚠️ Never use user input directly in `send_file` paths — directory traversal risk.

### Live streaming (SSE — Server-Sent Events)

```ruby
class EventsController < ApplicationController
  include ActionController::Live

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"  # disable Nginx buffering

    sse = SSE.new(response.stream, event: "message")

    10.times do |i|
      sse.write({ count: i })
      sleep 1
    end
  rescue ActionController::Live::ClientDisconnected
    # Client disconnected, that's fine
  ensure
    response.stream.close  # ALWAYS close
  end
end
```

**Important streaming caveats:**
- Each stream creates a new thread — don't create too many
- WEBrick buffers everything — use Puma for streaming
- Always `ensure` the stream is closed
- Headers must be set BEFORE first `write`

---

## Request and Response Objects

### Request properties

```ruby
request.method              # "GET", "POST", "PUT", "PATCH", "DELETE"
request.get?                # true/false (also post?, put?, patch?, delete?, head?)
request.xhr?                # AJAX request?
request.format              # Mime::HTML, Mime::JSON, etc.
request.content_type        # "application/json", etc.

# URLs
request.url                 # "https://example.com/posts?page=2"
request.original_url        # same, but before any rewrites
request.host                # "example.com"
request.domain              # "example.com"
request.port                # 443
request.protocol            # "https://"
request.path                # "/posts"
request.query_string        # "page=2"

# Client info
request.remote_ip           # client IP (respects X-Forwarded-For)
request.user_agent          # browser user agent string
request.headers["Accept"]   # any header

# Parameter sources
request.query_parameters    # from URL query string only
request.request_parameters  # from POST body only
request.path_parameters     # from route matching only
```

### Response properties

```ruby
response.body               # response body string
response.status             # numeric status code
response.headers            # header hash
response.content_type       # "text/html"
response.charset            # "utf-8"
response.location           # redirect URL, if any

# Set custom headers
response.headers["X-Request-Id"] = SecureRandom.uuid
response.headers["Cache-Control"] = "no-store"
```

---

## Health Check Endpoint

Built into Rails — available at `/up` by default:
- Returns **200** if app booted successfully
- Returns **500** if an exception occurred during boot

### Customize the path

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "health" => "rails/health#show", as: :rails_health_check
end
```

### Custom health check with dependency checks

```ruby
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    checks = {
      database: database_connected?,
      redis: redis_connected?,
      migrations: migrations_current?
    }

    status = checks.values.all? ? :ok : :service_unavailable
    render json: checks, status: status
  end

  private
    def database_connected?
      ActiveRecord::Base.connection.active?
    rescue
      false
    end

    def redis_connected?
      Redis.current.ping == "PONG"
    rescue
      false
    end

    def migrations_current?
      !ActiveRecord::Base.connection.migration_context.needs_migration?
    rescue
      false
    end
end
```

---

## API Controllers

### Inheriting from ActionController::API

```ruby
# app/controllers/api/base_controller.rb
class Api::BaseController < ActionController::API
  # No CSRF protection (APIs use token auth)
  # No cookie/session middleware
  # No flash
  # No asset helpers

  before_action :authenticate_token

  private
    def authenticate_token
      authenticate_or_request_with_http_token do |token, _options|
        @current_user = User.find_by(api_token: token)
      end
    end
end
```

`ActionController::API` is lighter than `ActionController::Base` — it excludes middleware for cookies, sessions, flash, CSRF, and views.

### Wrap Parameters (automatic JSON wrapping)

When `Content-Type: application/json`, Rails can auto-wrap params under the controller's model name:

```ruby
# POST /api/users with body: { "name": "Jo", "email": "jo@ex.com" }
# params becomes: { "name" => "Jo", "email" => "jo@ex.com", "user" => { "name" => "Jo", "email" => "jo@ex.com" } }
```

This is enabled by default (`config.action_controller.wrap_parameters_by_default = true`). Disable with:

```ruby
config.action_controller.wrap_parameters_by_default = false
```

### Standard API response pattern

```ruby
class Api::V1::PostsController < Api::BaseController
  def index
    posts = Post.all
    render json: posts
  end

  def show
    post = Post.find(params.expect(:id))
    render json: post
  end

  def create
    post = Post.new(post_params)
    if post.save
      render json: post, status: :created, location: api_v1_post_url(post)
    else
      render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    post = Post.find(params.expect(:id))
    if post.update(post_params)
      render json: post
    else
      render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    post = Post.find(params.expect(:id))
    post.destroy!
    head :no_content
  end

  private
    def post_params
      params.expect(post: [:title, :body, :published])
    end
end
```

---

## default_url_options

Set global defaults for URL generation:

```ruby
class ApplicationController < ActionController::Base
  def default_url_options
    { locale: I18n.locale }
  end
end
```

Now all URL helpers include the locale:
```ruby
posts_path          # => "/posts?locale=en"
posts_path(locale: :fr)  # => "/posts?locale=fr"
```
