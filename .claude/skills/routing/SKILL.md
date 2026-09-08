---
name: routing
description: Expert guidance for defining routes in Rails applications. Use when adding routes, working with resources, nested routes, namespaces, path helpers, routes.rb, RESTful design, API routes, URL helpers, or any routing-related task. Covers resources, singular resources, nesting, namespace vs scope, constraints, concerns, member/collection routes, and route testing.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails routes*), Bash(bin/rails test test/routing*)
---

# Rails Routing Expert

Define clean, RESTful, minimal routes. Extra routes create unnecessary attack surface and confuse other developers reading `routes.rb`.

## Philosophy

1. **RESTful by default** — Use `resources` and `resource`. Custom routes are a smell.
2. **Minimal surface area** — Always use `only:` or `except:` to expose just what's needed.
3. **Path helpers everywhere** — Hardcoded URL strings break when routes change. Use `_path` and `_url` helpers.
4. **Shallow nesting only** — Don't nest resources more than 1 level deep; deeper nesting creates painful URLs and helper names.
5. **New resource > custom action** — If you're adding many custom actions, you need a new controller.

## When To Use This Skill

- Adding or modifying routes in `config/routes.rb`
- Deciding between namespace, scope, and module
- Nesting resources
- Adding member or collection routes
- Setting up API versioning
- Debugging route conflicts
- Testing routes

## Instructions

### Step 1: Check Existing Routes

**Inspect current routes before adding new ones** — duplicates and conflicts cause subtle bugs:

```bash
# Show all routes
bin/rails routes

# Filter by controller
bin/rails routes -c users

# Search by path or helper name
bin/rails routes -g admin

# Find unused routes (clean these up!)
bin/rails routes --unused
```

### Step 2: Use Resources Correctly

#### `resources` (plural) — For collections

Generates 7 routes: index, show, new, create, edit, update, destroy.

```ruby
# Generates all 7 routes — unused routes create dead endpoints and confuse devs
resources :articles

# Better — only generate what the controller actually implements
resources :articles, only: [:index, :show, :create]
```

**Ask: which actions does this controller actually implement?** Only route those.

#### `resource` (singular) — For singletons

Use when there's only ONE of something per user/context. No `index` action. No `:id` in URLs.

```ruby
# Current user's profile — there's only one
resource :profile, only: [:show, :edit, :update]

# Current user's session
resource :session, only: [:new, :create, :destroy]

# App-wide dashboard
resource :dashboard, only: :show
```

**⚠️ CRITICAL: `resource` (singular) still routes to a PLURAL controller.**
`resource :profile` → `ProfilesController` (not `ProfileController`)

Path helpers are singular: `profile_path` (not `profiles_path`), `edit_profile_path`.

**When to use singular vs plural:**
- Can the user have/see multiple? → `resources` (plural)
- Is there exactly one in context? → `resource` (singular)
- Does an `index` action make sense? → `resources` (plural)

### Step 3: Nest Resources (Max 1 Level Deep)

Nest when a child resource only makes sense within its parent.

```ruby
# GOOD — 1 level deep
resources :articles do
  resources :comments, only: [:index, :create, :destroy]
end
```

```ruby
# Avoid — 2+ levels creates unwieldy URLs and painful helper names
resources :users do
  resources :articles do
    resources :comments  # ← /users/1/articles/2/comments/3
  end
end
```

**Use shallow nesting when child has its own identity:**

```ruby
# GOOD — collection routes nested, member routes flat
resources :articles do
  resources :comments, shallow: true
end
# Creates:
#   /articles/:article_id/comments     (index, create, new)
#   /comments/:id                      (show, edit, update, destroy)
```

This gives you the parent context where it matters (creating/listing) and clean URLs for direct access.

**Nested path helpers include the parent:**
```ruby
article_comments_path(@article)           # GET /articles/1/comments
article_comment_path(@article, @comment)  # GET /articles/1/comments/5
# With shallow:
comment_path(@comment)                    # GET /comments/5
```

### Step 4: Namespace vs Scope vs Module

These three look similar but behave differently — mixing them up causes confusing routing bugs.

#### `namespace` — Changes EVERYTHING (path + module + helpers)

```ruby
namespace :admin do
  resources :articles, only: [:index, :show]
end
```
- Path: `/admin/articles`
- Controller: `Admin::ArticlesController` (in `app/controllers/admin/`)
- Helper: `admin_articles_path`

**Use for:** Admin panels, API versions, distinct sections with their own controllers.

#### `scope module:` — Changes MODULE only (not path)

```ruby
scope module: :admin do
  resources :articles, only: [:index, :show]
end
```
- Path: `/articles` (no prefix!)
- Controller: `Admin::ArticlesController`
- Helper: `articles_path`

**Use for:** Organizing controllers into subdirectories without changing URLs.

#### `scope path:` — Changes PATH only (not module)

```ruby
scope "/admin" do
  resources :articles, only: [:index, :show]
end
```
- Path: `/admin/articles`
- Controller: `ArticlesController` (no module!)
- Helper: `articles_path`

**Use for:** URL prefixes without separate controller namespaces.

#### Quick Reference

| Method | URL prefix | Controller module | Helper prefix |
|--------|-----------|------------------|---------------|
| `namespace :admin` | `/admin` | `Admin::` | `admin_` |
| `scope module: :admin` | none | `Admin::` | none |
| `scope "/admin"` | `/admin` | none | none |

**When in doubt, use `namespace`.** It's the most explicit and least surprising.

### Step 5: Member vs Collection Routes

When you need routes beyond the standard 7 RESTful actions.

#### Member routes — Act on ONE specific record (requires `:id`)

```ruby
resources :articles, only: [:index, :show] do
  member do
    patch :publish      # PATCH /articles/:id/publish
    patch :archive      # PATCH /articles/:id/archive
  end
end
```

Generates: `publish_article_path(@article)`, `archive_article_path(@article)`

#### Collection routes — Act on the collection (no `:id`)

```ruby
resources :articles, only: [:index, :show] do
  collection do
    get :search         # GET /articles/search
    get :drafts         # GET /articles/drafts
    delete :clear_all   # DELETE /articles/clear_all
  end
end
```

Generates: `search_articles_path`, `drafts_articles_path`

#### Shorthand (single route)

```ruby
resources :photos do
  get :preview, on: :member       # GET /photos/:id/preview
  get :search, on: :collection    # GET /photos/search
end
```

**⚠️ STOP — Do you actually need a custom action?**

If you're adding more than 2 custom actions, you probably need a new resource:

```ruby
# BAD — too many custom actions on one resource
resources :articles do
  member do
    patch :publish
    patch :unpublish
    patch :archive
    patch :unarchive
    patch :feature
  end
end

# GOOD — extract a new resource
resources :articles, only: [:index, :show]
resources :article_publications, only: [:create, :destroy]  # publish/unpublish
resources :article_archives, only: [:create, :destroy]      # archive/unarchive
```

### Step 6: Route Concerns (DRY Shared Patterns)

When multiple resources share the same nested routes:

```ruby
concern :commentable do
  resources :comments, only: [:index, :create, :destroy]
end

concern :taggable do
  resources :tags, only: [:index, :create, :destroy]
end

resources :articles, concerns: [:commentable, :taggable]
resources :photos, concerns: [:commentable]
resources :videos, concerns: [:commentable, :taggable]
```

### Step 7: Constraints

#### Segment constraints (validate params)

```ruby
resources :users, constraints: { id: /\d+/ }
```

#### Request constraints (subdomain, format, etc.)

```ruby
constraints subdomain: "api" do
  namespace :api do
    resources :articles, only: [:index, :show]
  end
end
```

#### Advanced constraints (custom logic)

```ruby
# Lambda
get "*path", to: "errors#not_found",
  constraints: lambda { |req| !req.path.start_with?("/admin") }

# Object (responds to matches?)
class ApiConstraint
  def matches?(request)
    request.headers["Accept"]&.include?("application/json")
  end
end

constraints ApiConstraint.new do
  resources :articles, only: [:index, :show]
end
```

### Step 8: Root Route

Always define a root route:

```ruby
root "pages#home"
```

Namespaced roots:

```ruby
namespace :admin do
  root "dashboard#show"  # /admin → Admin::DashboardController#show
end
```

### Step 9: Redirects

```ruby
# Simple redirect (301 by default)
get "/old-path", to: redirect("/new-path")

# With status code
get "/old-path", to: redirect("/new-path", status: 302)

# Dynamic redirect
get "/articles/:id", to: redirect("/posts/%{id}")
```

### Step 10: Mount Engines

```ruby
mount Sidekiq::Web => "/sidekiq"
mount ActionCable.server => "/cable"
```

### Step 11: API Routes

```ruby
namespace :api do
  namespace :v1 do
    resources :articles, only: [:index, :show, :create, :update, :destroy]
    resources :users, only: [:show]
  end
end
```

**For API-only controllers**, use `defaults: { format: :json }`:

```ruby
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    resources :articles, only: [:index, :show]
  end
end
```

### Step 12: Direct and Resolve (Custom URL Helpers)

#### `direct` — Create custom URL helpers

```ruby
direct :homepage do
  "https://example.com"
end
# homepage_url => "https://example.com"

direct :cdn_image do |model|
  "https://cdn.example.com/#{model.image_path}"
end
# cdn_image_url(@photo) => "https://cdn.example.com/photos/1.jpg"
```

#### `resolve` — Customize polymorphic routing for models

Required when using `resource` (singular) with `form_with`:

```ruby
resource :basket, only: [:show, :update]
resolve("Basket") { [:basket] }

# Now form_with(model: @basket) generates /basket (not /baskets/:id)
```

## Route File Organization

Order your `config/routes.rb` like this:

```ruby
Rails.application.routes.draw do
  # 1. Root
  root "pages#home"

  # 2. Authentication / sessions
  resource :session, only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]

  # 3. Core resources (most used first)
  resources :articles do
    resources :comments, only: [:index, :create], shallow: true
  end

  # 4. Namespaced sections
  namespace :admin do
    root "dashboard#show"
    resources :users
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :articles, only: [:index, :show]
    end
  end

  # 5. Utility routes
  get "up", to: "rails/health#show", as: :rails_health_check

  # 6. Catch-all (if needed — put LAST)
  get "*path", to: "errors#not_found"
end
```

## Testing Routes

```ruby
# test/routing/articles_routing_test.rb
class ArticlesRoutingTest < ActionDispatch::IntegrationTest
  test "routes to articles#index" do
    assert_routing "/articles", controller: "articles", action: "index"
  end

  test "routes to articles#show" do
    assert_routing "/articles/1", controller: "articles", action: "show", id: "1"
  end

  test "generates correct path" do
    assert_generates "/articles/1", controller: "articles", action: "show", id: "1"
  end

  test "recognizes route" do
    assert_recognizes(
      { controller: "articles", action: "create" },
      { path: "/articles", method: :post }
    )
  end
end
```

## Anti-Patterns

1. **Generating all 7 routes when you need 2** — Always use `only:` or `except:`
2. **Nesting deeper than 1 level** — Flatten with shallow or separate resources
3. **Hardcoding paths** — Hardcoded strings break when routes change; use `article_path(@article)` instead of `"/articles/#{@article.id}"`
4. **Using `match ... via: :all`** — Exposing all HTTP verbs creates security surface; be explicit
5. **Too many custom member/collection actions** — Extract a new resource instead
6. **Confusing namespace/scope/module** — Check the table in Step 4
7. **`resource` when you mean `resources`** — Singular = one thing, no index, no `:id`
8. **Missing `only:`/`except:` on nested resources** — Nested routes bloat fast
9. **Forgetting `resolve` with singular `resource`** — `form_with` will break without it
10. **Route order bugs** — More specific routes go above general ones (Rails matches top-down, first match wins)

## Debugging

```bash
# See what a specific URL maps to
bin/rails routes -g "GET /articles"

# Check for conflicts
bin/rails routes | grep articles

# In rails console
Rails.application.routes.url_helpers.articles_path
app.edit_article_path(Article.first)
```

For detailed patterns, examples, and edge cases, see `reference.md` in this skill directory.
