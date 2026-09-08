# Routing Reference

Detailed patterns, examples, and edge cases for Rails routing. See `SKILL.md` for core guidance.

## Table of Contents
- [Resources: The Full Picture](#resources-the-full-picture)
- [Nested Resources](#nested-resources)
- [Namespace vs Scope: Detailed Comparison](#namespace-vs-scope-detailed-comparison)
- [Member and Collection Routes: Patterns](#member-and-collection-routes-patterns)
- [Route Concerns](#route-concerns)
- [Constraints](#constraints)
- [Path Helpers: Best Practices](#path-helpers-best-practices)
- [Redirects](#redirects)
- [Mounting Engines and Rack Apps](#mounting-engines-and-rack-apps)
- [Direct and Resolve](#direct-and-resolve)
- [API Routing Patterns](#api-routing-patterns)
- [Non-Resourceful Routes](#non-resourceful-routes)
- [Wildcard / Globbing Routes](#wildcard--globbing-routes)
- [Breaking Up Large Route Files](#breaking-up-large-route-files)
- [Route Testing](#route-testing)
- [Customizing Resources](#customizing-resources)
- [Common Patterns](#common-patterns)
- [Edge Cases and Gotchas](#edge-cases-and-gotchas)

---

## Resources: The Full Picture

### Plural Resources (`resources`)

```ruby
resources :photos
```

Generates 7 routes:

| Verb | Path | Action | Helper |
|------|------|--------|--------|
| GET | /photos | index | `photos_path` |
| GET | /photos/new | new | `new_photo_path` |
| POST | /photos | create | `photos_path` |
| GET | /photos/:id | show | `photo_path(photo)` |
| GET | /photos/:id/edit | edit | `edit_photo_path(photo)` |
| PATCH/PUT | /photos/:id | update | `photo_path(photo)` |
| DELETE | /photos/:id | destroy | `photo_path(photo)` |

Multiple resources in one line:

```ruby
resources :photos, :books, :videos
```

### Singular Resource (`resource`)

```ruby
resource :profile
```

Generates 6 routes (no `index`, no `:id` in URLs):

| Verb | Path | Action | Helper |
|------|------|--------|--------|
| GET | /profile/new | new | `new_profile_path` |
| POST | /profile | create | `profile_path` |
| GET | /profile | show | `profile_path` |
| GET | /profile/edit | edit | `edit_profile_path` |
| PATCH/PUT | /profile | update | `profile_path` |
| DELETE | /profile | destroy | `profile_path` |

**Key facts about singular resources:**
- Routes to a **plural** controller: `resource :profile` → `ProfilesController`
- No `:id` parameter — the controller determines "which one" from context (e.g., `current_user.profile`)
- Use `resolve` if you need `form_with` to work with model instances:

```ruby
resource :basket
resolve("Basket") { [:basket] }
```

### Restricting Routes with `only:` and `except:`

```ruby
# Whitelist — only these actions
resources :articles, only: [:index, :show]

# Blacklist — everything except these
resources :articles, except: [:destroy]
```

**Prefer `only:` over `except:`** — it's explicit about what exists.

---

## Nested Resources

### Basic Nesting

```ruby
resources :magazines do
  resources :ads, only: [:index, :show, :create]
end
```

Generates nested paths like `/magazines/:magazine_id/ads` and `/magazines/:magazine_id/ads/:id`.

**The child controller receives `params[:magazine_id]`** — you must scope queries:

```ruby
class AdsController < ApplicationController
  def index
    @magazine = Magazine.find(params[:magazine_id])
    @ads = @magazine.ads
  end
end
```

### Shallow Nesting

Collection actions stay nested (need parent context). Member actions go flat (the record's `:id` is enough).

```ruby
resources :articles do
  resources :comments, shallow: true
end
```

Equivalent to:

```ruby
resources :articles do
  resources :comments, only: [:index, :new, :create]
end
resources :comments, only: [:show, :edit, :update, :destroy]
```

Generated routes:

| Verb | Path | Action | Helper |
|------|------|--------|--------|
| GET | /articles/:article_id/comments | index | `article_comments_path(@article)` |
| POST | /articles/:article_id/comments | create | `article_comments_path(@article)` |
| GET | /articles/:article_id/comments/new | new | `new_article_comment_path(@article)` |
| GET | /comments/:id | show | `comment_path(@comment)` |
| GET | /comments/:id/edit | edit | `edit_comment_path(@comment)` |
| PATCH/PUT | /comments/:id | update | `comment_path(@comment)` |
| DELETE | /comments/:id | destroy | `comment_path(@comment)` |

You can also wrap multiple nested resources in `shallow`:

```ruby
shallow do
  resources :articles do
    resources :comments
    resources :quotes
  end
end
```

### Why 1-Level Max?

Deep nesting creates:
- **Unwieldy URLs:** `/publishers/1/magazines/2/photos/3`
- **Fragile helpers:** `publisher_magazine_photo_path(@pub, @mag, @photo)`
- **Coupling:** Every controller needs all ancestor params

**Fix deeply nested resources by flattening:**

```ruby
# BAD
resources :users do
  resources :posts do
    resources :comments
  end
end

# GOOD
resources :users do
  resources :posts, only: [:index, :create], shallow: true
end
resources :posts do
  resources :comments, only: [:index, :create], shallow: true
end
```

---

## Namespace vs Scope: Detailed Comparison

### `namespace` — The Kitchen Sink

Changes URL path, controller module, AND helper prefix all at once.

```ruby
namespace :admin do
  resources :articles
end
```

- URL: `/admin/articles`
- Controller: `Admin::ArticlesController` (file: `app/controllers/admin/articles_controller.rb`)
- Helpers: `admin_articles_path`, `new_admin_article_path`, `admin_article_path(@article)`

### `scope module:` — Organize Controllers, Keep URLs

```ruby
scope module: :v2 do
  resources :articles
end
# Same as: resources :articles, module: :v2
```

- URL: `/articles` (unchanged)
- Controller: `V2::ArticlesController` (file: `app/controllers/v2/articles_controller.rb`)
- Helpers: `articles_path` (unchanged)

**Use case:** You're refactoring controllers into a subdirectory but don't want to change URLs.

### `scope path:` — Change URL, Keep Controller

```ruby
scope "/admin" do
  resources :articles
end
```

- URL: `/admin/articles`
- Controller: `ArticlesController` (no module!)
- Helpers: `articles_path` (unchanged — can cause collisions!)

**Use case:** Rare. Usually you want `namespace` instead.

### `scope` with `as:` — Add Helper Prefix

```ruby
scope "/admin", as: "admin" do
  resources :articles
end
```

- URL: `/admin/articles`
- Controller: `ArticlesController`
- Helpers: `admin_articles_path` (prefixed)

### Combining All Three

`namespace :admin` is shorthand for:

```ruby
scope "/admin", module: :admin, as: :admin do
  # ...
end
```

---

## Member and Collection Routes: Patterns

### Member Routes (operate on a specific record)

```ruby
resources :articles do
  member do
    patch :publish      # PATCH /articles/:id/publish
    patch :archive      # PATCH /articles/:id/archive
    get :preview        # GET   /articles/:id/preview
  end
end
```

- Requires `:id` in URL
- Helper: `publish_article_path(@article)`
- `params[:id]` available in action

### Collection Routes (operate on the resource as a whole)

```ruby
resources :articles do
  collection do
    get :search         # GET /articles/search
    get :recent         # GET /articles/recent
    post :import        # POST /articles/import
  end
end
```

- No `:id` in URL
- Helper: `search_articles_path`

### Shorthand

```ruby
resources :photos do
  get :preview, on: :member
  get :search, on: :collection
end
```

### When to Extract a New Resource

**Rule of thumb:** More than 2 custom actions = new resource.

```ruby
# BEFORE — too many custom actions
resources :orders do
  member do
    patch :ship
    patch :deliver
    patch :cancel
    patch :refund
  end
end

# AFTER — separate state-change resources
resources :orders, only: [:index, :show, :create]
resources :order_shipments, only: :create     # POST = ship the order
resources :order_cancellations, only: :create # POST = cancel the order
resources :order_refunds, only: :create       # POST = refund the order
```

---

## Route Concerns

### Defining Concerns

```ruby
concern :commentable do
  resources :comments, only: [:index, :create, :destroy]
end

concern :archivable do
  member do
    patch :archive
    patch :unarchive
  end
end
```

### Using Concerns

```ruby
resources :articles, concerns: [:commentable, :archivable]
resources :photos, concerns: :commentable
resources :videos, concerns: [:commentable, :archivable]
```

### Parameterized Concerns

```ruby
concern :paginatable do |options|
  collection do
    get :page, defaults: { per_page: options[:per_page] || 25 }
  end
end

resources :articles, concerns: :paginatable
resources :photos do
  concerns :paginatable, per_page: 50
end
```

---

## Constraints

### Segment Constraints

```ruby
# Only match numeric IDs
resources :users, constraints: { id: /\d+/ }

# Inline shorthand
get "photos/:id", to: "photos#show", id: /[A-Z]\d{5}/
```

### Format Constraints

```ruby
# Force JSON format
namespace :api, defaults: { format: :json } do
  resources :articles
end

# Constraint on format
get "articles/:id", to: "articles#show", constraints: { format: :json }
```

### Subdomain Constraints

```ruby
constraints subdomain: "api" do
  namespace :api do
    resources :articles
  end
end

constraints subdomain: "admin" do
  namespace :admin do
    resources :users
  end
end
```

### Custom Constraint Objects

```ruby
class AuthenticatedConstraint
  def matches?(request)
    request.session[:user_id].present?
  end
end

constraints AuthenticatedConstraint.new do
  root "dashboard#show"
end

# Fallback for unauthenticated
root "pages#landing"
```

### Lambda Constraints

```ruby
get "*path", to: "api#route",
  constraints: lambda { |req| req.headers["Accept"]&.include?("application/json") }
```

---

## Path Helpers: Best Practices

### Always Use Helpers

```ruby
# WRONG
link_to "Articles", "/articles"
redirect_to "/articles/#{@article.id}"

# RIGHT
link_to "Articles", articles_path
redirect_to article_path(@article)
# or simply:
redirect_to @article
```

### `_path` vs `_url`

- `_path` → relative: `/articles/1`
- `_url` → absolute: `https://example.com/articles/1`

**Use `_path` in views and controllers.** Use `_url` in:
- Mailers (emails need absolute URLs)
- Redirects after OAuth
- API responses with full URLs
- `redirect_to` (either works, `_path` is fine)

### Polymorphic Path Helpers

```ruby
# Rails resolves the model to the right path helper
link_to "Show", @article                      # article_path(@article)
link_to "Show", [@magazine, @ad]              # magazine_ad_path(@magazine, @ad)
link_to "Edit", [:edit, @magazine, @ad]       # edit_magazine_ad_path(@magazine, @ad)

# form_with uses polymorphic routing
form_with model: @article                      # POST /articles or PATCH /articles/:id
form_with model: [@magazine, @ad]              # POST /magazines/:id/ads or PATCH
```

### Finding Helper Names

```bash
# See all helpers
bin/rails routes

# Look at the Prefix column — append _path or _url
#    Prefix    Verb   URI Pattern
#    articles  GET    /articles(.:format)
# → articles_path, articles_url
```

---

## Redirects

### Simple

```ruby
get "/old", to: redirect("/new")
```

### With Dynamic Segments

```ruby
get "/stories/:id", to: redirect("/articles/%{id}")
```

### With Block (complex logic)

```ruby
get "/stories/:name", to: redirect { |params, req|
  "/articles/#{params[:name].parameterize}"
}
```

### Custom Status

```ruby
get "/old", to: redirect("/new", status: 302)  # Default is 301
```

---

## Mounting Engines and Rack Apps

```ruby
# Sidekiq web UI
mount Sidekiq::Web => "/sidekiq"

# Action Cable
mount ActionCable.server => "/cable"

# Custom Rack app
mount MyRackApp, at: "/my-app"

# Inline health check
get "/health", to: ->(env) { [200, {}, ["OK"]] }
```

**Protect mounted engines:**

```ruby
authenticate :user, ->(u) { u.admin? } do
  mount Sidekiq::Web => "/sidekiq"
end
```

---

## Direct and Resolve

### `direct` — Custom URL Helpers

```ruby
direct :homepage do
  "https://example.com"
end
# homepage_url => "https://example.com"

direct :cdn_asset do |model|
  if model.respond_to?(:image_path)
    "https://cdn.example.com/#{model.image_path}"
  else
    "https://cdn.example.com/default.png"
  end
end
```

### `resolve` — Polymorphic Routing Override

Essential with singular `resource`:

```ruby
resource :cart
resolve("Cart") { [:cart] }

# Without resolve: form_with(model: @cart) → ERROR (tries /carts/:id)
# With resolve:    form_with(model: @cart) → /cart (correct!)
```

---

## API Routing Patterns

### Versioned API

```ruby
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    resources :articles, only: [:index, :show, :create, :update, :destroy]
    resources :users, only: [:show, :index]
  end

  namespace :v2 do
    resources :articles, only: [:index, :show, :create, :update, :destroy]
  end
end
```

### API with Subdomain

```ruby
constraints subdomain: "api" do
  scope module: :api do
    namespace :v1 do
      resources :articles
    end
  end
end
```

### API with Header-Based Versioning

```ruby
class ApiVersion
  def initialize(version)
    @version = version
  end

  def matches?(request)
    request.headers["Accept"]&.include?("application/vnd.myapp.v#{@version}")
  end
end

scope module: :v2, constraints: ApiVersion.new(2) do
  resources :articles
end

scope module: :v1, constraints: ApiVersion.new(1) do
  resources :articles
end
```

---

## Non-Resourceful Routes

When `resources` doesn't fit, use explicit verb methods.

```ruby
# Named route
get "login", to: "sessions#new", as: :login
post "login", to: "sessions#create"
delete "logout", to: "sessions#destroy", as: :logout

# With parameters
get "photos/:id/:user_id", to: "photos#show"

# With defaults
get "articles", to: "articles#index", defaults: { format: "json" }
```

**Avoid `match ... via: :all`** — always be explicit about HTTP verbs.

---

## Wildcard / Globbing Routes

```ruby
# Catch-all (must be LAST)
get "*path", to: "errors#not_found"

# Multi-segment capture
get "docs/*section/:page", to: "docs#show"
# /docs/api/v2/authentication → params[:section] = "api/v2", params[:page] = "authentication"
```

---

## Breaking Up Large Route Files

For large apps (hundreds of routes):

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  draw(:api)    # loads config/routes/api.rb
  draw(:admin)  # loads config/routes/admin.rb
end
```

```ruby
# config/routes/api.rb
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    resources :articles
  end
end
```

**Don't wrap sub-files in `Rails.application.routes.draw`.** Just use the DSL directly.

**Only use `draw` if you really need it.** For most apps, a single organized `routes.rb` is better.

---

## Route Testing

### Three Built-in Assertions

```ruby
# Does this path map to this action?
assert_recognizes(
  { controller: "articles", action: "show", id: "1" },
  "/articles/1"
)

# Does this action generate this path?
assert_generates "/articles/1",
  controller: "articles", action: "show", id: "1"

# Both directions at once
assert_routing(
  { path: "/articles", method: :post },
  { controller: "articles", action: "create" }
)
```

### Testing with HTTP Verb

```ruby
assert_recognizes(
  { controller: "articles", action: "create" },
  { path: "/articles", method: :post }
)
```

### Integration Test Pattern

```ruby
class ArticlesRoutingTest < ActionDispatch::IntegrationTest
  test "index route" do
    assert_routing "/articles", controller: "articles", action: "index"
  end

  test "nested comments route" do
    assert_routing "/articles/1/comments",
      controller: "comments", action: "index", article_id: "1"
  end

  test "admin namespace" do
    assert_routing "/admin/users",
      controller: "admin/users", action: "index"
  end
end
```

---

## Customizing Resources

### Custom Controller

```ruby
resources :photos, controller: "images"
# /photos → ImagesController (helpers still use photos_path)
```

### Custom Path

```ruby
resources :photos, path: "images"
# /images → PhotosController (helpers still use photos_path)
```

### Custom Param

```ruby
resources :videos, param: :identifier
# /videos/:identifier → params[:identifier]
```

Pair with `to_param` on the model:

```ruby
class Video < ApplicationRecord
  def to_param
    identifier
  end
end
```

### Custom Path Names (i18n)

```ruby
resources :photos, path_names: { new: "hacer", edit: "editar" }
# /photos/hacer, /photos/1/editar
```

### Custom Helper Names

```ruby
resources :photos, as: "images"
# images_path, new_image_path, etc.
```

---

## Common Patterns

### Authentication Routes

```ruby
# Session-based auth
resource :session, only: [:new, :create, :destroy]
resources :registrations, only: [:new, :create]
resources :passwords, only: [:new, :create, :edit, :update]

get "login", to: "sessions#new", as: :login
delete "logout", to: "sessions#destroy", as: :logout
```

### Soft Delete / Archive

```ruby
resources :articles do
  member do
    patch :archive
    patch :restore
  end
end
```

### Dashboard (singleton)

```ruby
resource :dashboard, only: :show
```

### Search

```ruby
resources :articles do
  collection do
    get :search
  end
end
```

### Pagination in URLs

```ruby
# Usually handled by query params, not routes
# GET /articles?page=2 — no route changes needed
```

---

## Edge Cases and Gotchas

### Route Order Matters

Routes match top-to-bottom. Put specific routes ABOVE general ones:

```ruby
# WRONG — resources catches "search" as an :id
resources :articles
get "articles/search", to: "articles#search"  # Never reached!

# RIGHT — specific route first
get "articles/search", to: "articles#search"
resources :articles
# Or better: use collection route (see SKILL.md Step 5)
```

### `resource` Maps to Plural Controller

This trips up everyone:

```ruby
resource :profile     # → ProfilesController (PLURAL!)
resource :session      # → SessionsController (PLURAL!)
resource :dashboard    # → DashboardsController (PLURAL!)
```

If your controller is `ProfileController` (singular), you need:

```ruby
resource :profile, controller: "profile"
```

### Nested Resource Param Names

```ruby
resources :magazines do
  resources :ads
end
```

In `AdsController`:
- Parent ID: `params[:magazine_id]` (not `params[:id]`)
- Ad ID: `params[:id]`

### `format` Is Implicit

Every route implicitly accepts a format suffix: `/articles/1.json`. To disable:

```ruby
get "articles/:id", to: "articles#show", format: false
```

To require format:

```ruby
get "articles/:id", to: "articles#show", format: true
```

### Don't Use `match` Without `via:`

```ruby
# DANGEROUS — accepts ALL HTTP verbs
match "photos", to: "photos#index"  # Rails will raise an error

# CORRECT
match "photos", to: "photos#index", via: [:get, :post]
```

Rails requires `via:` on `match` to prevent accidental exposure to all verbs.
