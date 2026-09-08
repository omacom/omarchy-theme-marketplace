# Sessions and Cookies

Configuration, stores, jar types, and usage patterns.

## Sessions — Configuration and Stores

### Available stores

| Store | Description | Pros | Cons |
|-------|-------------|------|------|
| `CookieStore` (default) | All data in the cookie | Zero setup, no server state | 4KB limit, all data sent every request |
| `CacheStore` | Uses Rails.cache | Leverages existing cache infra | Sessions lost on cache eviction |
| `ActiveRecordStore` | Database storage | Unlimited size, persistent | Requires gem + migration, slower |

### Configuration

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: "_myapp_session",
  expire_after: 12.hours

# Cache store
Rails.application.config.session_store :cache_store,
  key: "_myapp_session",
  expire_after: 30.minutes

# Domain sharing
Rails.application.config.session_store :cookie_store,
  key: "_myapp_session",
  domain: ".example.com"  # share session across subdomains
```

### reset_session — ALWAYS on login

```ruby
def create
  user = User.authenticate_by(email: params[:email], password: params[:password])
  if user
    reset_session  # prevents session fixation attacks
    session[:current_user_id] = user.id
    redirect_to root_path
  else
    flash.now[:alert] = "Invalid credentials"
    render :new, status: :unprocessable_entity
  end
end
```

---

## Cookies — All Jar Types

| Jar | Method | Tamper-proof? | Encrypted? | Use case |
|-----|--------|---------------|------------|----------|
| Basic | `cookies[:key]` | No | No | Non-sensitive preferences |
| Permanent | `cookies.permanent[:key]` | No | No | Long-lived preferences |
| Signed | `cookies.signed[:key]` | Yes | No | User IDs, tokens (readable but can't be faked) |
| Encrypted | `cookies.encrypted[:key]` | Yes | Yes | Sensitive data |

### Chaining jars

```ruby
cookies.permanent.signed[:user_id] = current_user.id   # permanent + signed
cookies.permanent.encrypted[:token] = session_token      # permanent + encrypted
```

### Options

```ruby
cookies[:theme] = {
  value: "dark",
  expires: 1.year,
  path: "/admin",       # only sent for /admin paths
  domain: ".example.com", # shared across subdomains
  secure: true,          # HTTPS only
  httponly: true,         # not accessible via JavaScript
  same_site: :lax        # CSRF protection (:strict, :lax, :none)
}
```

### Serialization

Default serializer is `:json`. Be aware that `Date`, `Time`, and `Symbol` are serialized as strings:

```ruby
cookies.encrypted[:date] = Date.today
cookies.encrypted[:date]  # => "2024-03-20" (String, not Date!)
```
