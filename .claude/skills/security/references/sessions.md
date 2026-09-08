# Session Security Deep Dive

## Session Fixation Attack

1. Attacker gets a valid session ID from your app
2. Tricks victim into using that session ID
3. Victim logs in — session is now authenticated
4. Attacker uses the same session ID — they're now logged in as victim

**Defense: Always reset the session on login.**

```ruby
def create
  if user = User.authenticate_by(email_address: params[:email], password: params[:password])
    reset_session  # Invalidates old session, creates new one
    session[:user_id] = user.id
    redirect_to root_path
  end
end
```

## Session Storage

```ruby
# Default: CookieStore (encrypted, 4KB limit)
# Good for: session IDs, CSRF tokens, flash messages
# Bad for: large data, data that needs server-side invalidation

# For server-side sessions (better control):
# gem "redis-session-store"
Rails.application.config.session_store :redis_session_store,
  key: "_myapp_session",
  expire_after: 1.day
```

## Session Data Rules

```ruby
# GOOD — store only IDs
session[:user_id] = user.id
session[:cart_id] = cart.id

# BAD — store actual data (replay attacks, size limits)
session[:cart_items] = [{ product: "Widget", price: 9.99 }]
session[:user_role] = "admin"  # Attacker can replay old cookie with admin role
```

## Cookie Security Flags

```ruby
# In production, Rails sets these when force_ssl = true:
# Secure: true (only sent over HTTPS)
# HttpOnly: true (not accessible to JavaScript — prevents XSS cookie theft)
# SameSite: Lax (prevents CSRF from most cross-site contexts)

# You can set custom cookies securely:
cookies.encrypted[:preference] = {
  value: "dark_mode",
  httponly: true,
  secure: Rails.env.production?,
  same_site: :lax,
  expires: 1.year
}
```
