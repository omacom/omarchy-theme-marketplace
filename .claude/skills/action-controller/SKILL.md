---
name: action-controller
description: Expert guidance for writing Rails controllers with Action Controller. Use when writing controller actions, strong parameters, before_action filters, rendering responses, redirects, flash messages, sessions, cookies, rescue_from error handling, streaming, CSRF protection, or HTTP authentication. Covers params permitting (especially nested params — the #1 source of agent bugs), callbacks, request/response objects, and security. Trigger on "controller", "action", "strong parameters", "params", "before_action", "redirect", "render", "flash", "session", "cookies", "rescue_from", "CSRF", "permit", "expect", "filters", "callbacks".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate controller*), Bash(bin/rails routes*)
---

# Rails Action Controller Expert

Write correct, secure, and idiomatic Rails controllers following Rails 8.1 conventions.

## Philosophy

1. **Thin controllers** — Business logic belongs in models/services, not controllers
2. **Strong parameters protect against mass assignment** — Raw params let attackers set any attribute (admin flags, user IDs, etc.)
3. **Convention over configuration** — Follow RESTful patterns; fight the urge to add custom actions
4. **Fail secure** — Default to restricting access, then open up selectively
5. **One controller, one resource** — If your controller handles two resources, split it

## When To Use This Skill

- Writing new controller actions (CRUD or custom)
- Permitting parameters (especially nested hashes/arrays — this is where bugs live)
- Adding before_action filters for auth/authorization
- Setting up rescue_from for error handling
- Working with sessions, cookies, or flash messages
- Rendering responses or redirecting
- Implementing streaming or file downloads
- Configuring CSRF protection or HTTP auth

## Instructions

### Step 1: Check Existing Patterns

**Look at the project's existing controllers first** — consistency with the codebase matters more than textbook patterns:

```bash
# See what ApplicationController provides
cat app/controllers/application_controller.rb

# Find similar controllers
ls app/controllers/

# Check for shared concerns
ls app/controllers/concerns/

# Check routes for the resource
bin/rails routes | grep resource_name
```

Consistency beats "best practice."

### Step 2: Controller Structure

Follow this ordering inside every controller:

```ruby
class ArticlesController < ApplicationController
  # 1. Includes/concerns
  include Searchable

  # 2. Constants (if any)
  ITEMS_PER_PAGE = 25

  # 3. Callbacks — order matters, they run top-to-bottom
  before_action :authenticate_user!
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  before_action :authorize_article, only: [:edit, :update, :destroy]

  # 4. Public actions (RESTful order: index, show, new, create, edit, update, destroy)
  def index
    @articles = Article.all
  end

  def show; end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Article updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    redirect_to articles_path, notice: "Article deleted.", status: :see_other
  end

  # 5. Private methods
  private

    def set_article
      @article = Article.find(params.expect(:id))
    end

    def authorize_article
      redirect_to articles_path, alert: "Not authorized." unless @article.user == current_user
    end

    def article_params
      params.expect(article: [:title, :body, :published])
    end
end
```

### Step 3: Strong Parameters

This is where most controller bugs come from — especially with nested hashes and arrays.

#### Use `expect` (Rails 8+) Over `require` + `permit`

```ruby
# ✅ Rails 8+ — prefer expect (combines require + permit)
def article_params
  params.expect(article: [:title, :body, :published])
end

# ⚠️ Older style — still works but expect is preferred
def article_params
  params.require(:article).permit(:title, :body, :published)
end
```

#### Nested Hashes — The Danger Zone

```ruby
# Nested hash (belongs_to address, has fields)
# Form sends: { user: { name: "Jo", address: { street: "123 Main", city: "NY" } } }
def user_params
  params.expect(user: [:name, address: [:street, :city, :zip]])
end

# ⚠️ Wrong — this permits NOTHING inside address
def user_params
  params.expect(user: [:name, :address])  # address is a hash, not a scalar!
end
```

#### Arrays of Scalars

```ruby
# Array of simple values: { article: { title: "Hi", tag_ids: [1, 2, 3] } }
def article_params
  params.expect(article: [:title, tag_ids: []])
end
```

#### Arrays of Hashes (accepts_nested_attributes_for)

```ruby
# Array of nested objects — NOTE THE DOUBLE ARRAY SYNTAX [[...]]
# { project: { name: "X", tasks_attributes: [{ title: "A" }, { title: "B" }] } }
def project_params
  params.expect(project: [:name, tasks_attributes: [[:title, :done, :id, :_destroy]]])
end
```

**Double array `[[...]]`** = "I expect an array of hashes, each with these keys."
This is the Rails 8 `expect` syntax. Agents get this wrong constantly.

#### Arbitrary Hash (Use Sparingly)

```ruby
# When you genuinely can't enumerate keys (e.g., JSON metadata blob)
def product_params
  params.expect(product: [:name, metadata: {}])
end
# ⚠️ metadata: {} permits ANY keys — only use when truly dynamic
```

#### Common Gotchas

| Bug | Fix |
|-----|-----|
| `permit(:tags)` when tags is an array | `permit(tags: [])` |
| `permit(:address)` when address is a hash | `permit(address: [:street, :city])` |
| `permit(:images)` for file uploads | `permit(images: [])` for multiple files |
| Nested attributes without `_destroy` and `id` | `permit(items_attributes: [[:name, :id, :_destroy]])` |
| Using `permit!` to "just make it work" | Enumerate your params — `permit!` allows attackers to set any attribute |

### Step 4: Callbacks (before_action, after_action, around_action)

#### before_action

```ruby
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  # Skip inherited callbacks selectively
  skip_before_action :authenticate_user!, only: [:index, :show]

  private
    def set_post
      @post = Post.find(params.expect(:id))
    end
end
```

**Key rules:**
- Callbacks run in declaration order — put auth before resource loading
- A callback that renders or redirects **halts the chain** (remaining callbacks and the action won't run)
- Use `only:` / `except:` to scope callbacks to specific actions
- `skip_before_action` only works for callbacks inherited from parent classes or registered earlier

#### around_action

```ruby
around_action :wrap_in_transaction, only: [:create, :update]

private
  def wrap_in_transaction
    ActiveRecord::Base.transaction do
      yield  # executes the action
    end
  end
```

**The `yield` is required** — without it the action never executes.

### Step 5: Rendering Responses

```ruby
# Implicit render — renders app/views/posts/index.html.erb
def index
  @posts = Post.all
  # no explicit render needed
end

# Explicit render of a different template
render :new                           # same controller, different action template
render "posts/new"                    # cross-controller template
render plain: "OK"                    # plain text
render json: @post                    # JSON
render json: @post, status: :created  # JSON with status
render html: "<h1>Hi</h1>".html_safe  # raw HTML
render inline: "<%= 'hi' %>"          # inline ERB (avoid)
render nothing: true, status: :ok      # empty body (deprecated — use head)

# head — response with no body
head :no_content          # 204
head :created, location: post_url(@post)

# Render with status (Turbo requires it for error responses)
render :new, status: :unprocessable_entity   # 422 — required for Turbo
render :edit, status: :unprocessable_entity
```

**For Turbo/Hotwire:** Failed form submissions need `status: :unprocessable_entity` (422) — without it, Turbo ignores the response and the user sees no error feedback.

#### respond_to for Multiple Formats

```ruby
def show
  @post = Post.find(params.expect(:id))

  respond_to do |format|
    format.html  # renders show.html.erb
    format.json { render json: @post }
    format.pdf { send_data generate_pdf(@post), filename: "post.pdf" }
  end
end
```

### Step 6: Redirects

```ruby
redirect_to @post                          # redirect to show
redirect_to posts_path                     # redirect to index
redirect_to root_path, notice: "Done!"     # with flash notice
redirect_to root_path, alert: "Oops!"      # with flash alert
redirect_to root_path, status: :see_other  # 303 — use for DELETE actions

# Redirect back (with fallback)
redirect_back fallback_location: root_path

# ⚠️ After DELETE, use status: :see_other (303)
# This prevents browsers from replaying the DELETE on redirect
def destroy
  @post.destroy!
  redirect_to posts_path, notice: "Deleted.", status: :see_other
end
```

### Step 7: Flash Messages

```ruby
# Set in redirect
redirect_to @post, notice: "Saved!"
redirect_to @post, alert: "Problem!"

# Set manually (available on NEXT request)
flash[:notice] = "Saved!"
flash[:alert] = "Problem!"

# Set for CURRENT request (use when rendering, not redirecting)
flash.now[:error] = "Could not save."
render :new, status: :unprocessable_entity

# Carry flash through an extra redirect
flash.keep
redirect_to another_path
```

**Rule of thumb:** `flash[...]` before `redirect_to`. `flash.now[...]` before `render`.

### Step 8: Sessions and Cookies

#### Sessions

```ruby
# Store
session[:current_user_id] = user.id

# Read
session[:current_user_id]

# Delete
session.delete(:current_user_id)

# Nuke everything (do this on login to prevent session fixation)
reset_session
```

#### Cookies

```ruby
# Basic (deleted when browser closes)
cookies[:theme] = "dark"

# With expiration
cookies[:theme] = { value: "dark", expires: 1.year }

# Permanent (20 years)
cookies.permanent[:locale] = "en"

# Signed (tamper-proof, but readable)
cookies.signed[:user_id] = current_user.id
cookies.signed[:user_id]  # => 42

# Encrypted (tamper-proof AND unreadable)
cookies.encrypted[:token] = "secret"
cookies.encrypted[:token]  # => "secret"

# Delete
cookies.delete(:theme)
```

### Step 9: Error Handling with rescue_from

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private
    def not_found
      respond_to do |format|
        format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
        format.json { render json: { error: "Not found" }, status: :not_found }
      end
    end

    def unprocessable(exception)
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: exception.message }
        format.json { render json: { error: exception.message }, status: :unprocessable_entity }
      end
    end

    def bad_request(exception)
      render json: { error: exception.message }, status: :bad_request
    end
end
```

**Don't rescue `Exception` or `StandardError`** — they catch things like `SystemExit` and `SyntaxError`, breaking Rails internals and hiding real bugs.

### Step 10: CSRF Protection

Enabled by default. Key points:

```ruby
# Default — raises exception on CSRF failure
protect_from_forgery with: :exception

# For API controllers — skip CSRF (use token auth instead)
class Api::BaseController < ActionController::API  # no CSRF by default
end
```

Turbo and `rails-ujs` handle CSRF automatically. For custom `fetch` calls, read the token from the `<meta name="csrf-token">` tag and send it as `X-CSRF-Token` header.

### Step 11: HTTP Auth, Streaming, Request/Response

```ruby
# Basic Auth — quick and dirty (admin panels, staging)
http_basic_authenticate_with name: "admin", password: ENV["ADMIN_PASSWORD"]

# Token Auth — for APIs
authenticate_or_request_with_http_token do |token, _options|
  ActiveSupport::SecurityUtils.secure_compare(token, ENV["API_TOKEN"])
end

# Send generated data as download
send_data pdf_content, filename: "report.pdf", type: "application/pdf"

# Send existing file
send_file Rails.root.join("storage/report.pdf"), filename: "report.pdf"

# Live streaming — always close the stream
include ActionController::Live
response.headers["Content-Type"] = "text/event-stream"
response.stream.write "data: hello\n\n"
ensure
  response.stream.close

# Useful request properties
request.remote_ip          # client IP
request.get? / request.post?  # method checks
request.headers["X-Custom"]
request.format             # Mime::HTML, Mime::JSON, etc.
request.variant = :mobile  # for device-specific views
```

## Anti-Patterns to Avoid

1. **Fat controllers** — Move business logic to models/services/form objects
2. **`permit!`** — Opens the door to mass assignment attacks; enumerate every permitted attribute
3. **`params[:foo]` directly in model calls** — Bypasses strong parameter filtering; go through the params method
4. **Skipping CSRF broadly** — Only skip for genuine API endpoints with token auth; CSRF protects against cross-site form submissions
5. **`rescue_from Exception`** — Catches syntax errors, SystemExit, and other things you don't want to swallow
6. **Nested `if/else` chains in actions** — Extract to service objects
7. **Multiple renders/redirects** — A controller action can only render or redirect once; use `and return` or early returns
8. **Missing status on error renders** — Turbo requires `status: :unprocessable_entity`
9. **Session for everything** — Session is 4KB max with CookieStore; use the database for big data
10. **Redirect after DELETE without `:see_other`** — Can cause browsers to replay the DELETE

## Quick Reference

See the `references/` directory for detailed patterns and examples:
- `references/strong-params.md` — Complete param permitting patterns (nested hashes, arrays, double array syntax)
- `references/callbacks.md` — All callback types, ordering rules, halting, skip patterns
- `references/rendering.md` — Full rendering options, redirects, flash messages, respond_to, variants
- `references/sessions-and-cookies.md` — Session stores, cookie jar types, configuration
- `references/security.md` — rescue_from, CSRF, HTTP auth, CSP, log filtering, Force SSL, browser version control
- `references/streaming.md` — send_data/send_file, SSE streaming, request/response objects, API controllers, health checks
