# CSRF Deep Dive

## How CSRF Works

Rails embeds a unique `authenticity_token` in every form and verifies it on POST/PATCH/PUT/DELETE requests. The token proves the request originated from your app, not a malicious third-party site.

## Token Flow

1. Rails generates a per-session CSRF token
2. `<%= csrf_meta_tags %>` embeds it in the layout (for Turbo/JS)
3. `form_with` / `form_for` automatically include a hidden `authenticity_token` field
4. Server verifies the token on every non-GET request

## Common Mistakes

```ruby
# MISTAKE: Skipping CSRF for webhook endpoints that also serve browsers
class WebhooksController < ApplicationController
  skip_forgery_protection  # Fine ONLY if this never uses cookie auth
end

# MISTAKE: Using protect_from_forgery with: :null_session globally
# This silently clears the session instead of raising — attacker gets a blank session
class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session  # BAD for browser apps
end

# CORRECT: Use :exception for browser apps, :null_session only for pure APIs
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end

class Api::BaseController < ActionController::API
  # Inherits from API — no session, no CSRF needed
  # BUT must authenticate via token header, not cookies
end
```

## CSRF with JavaScript/Turbo

Turbo automatically reads the CSRF token from meta tags. For custom fetch/XHR:

```javascript
// Read token from meta tag
const token = document.head.querySelector("meta[name=csrf-token]")?.content;

// Include in fetch requests
fetch("/posts", {
  method: "POST",
  headers: {
    "X-CSRF-Token": token,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({ post: { title: "New Post" } })
});
```

## API-Only Controllers

If your API uses token authentication (Bearer tokens, API keys) and never reads cookies, CSRF protection is unnecessary. But if your API shares cookies with the browser app, you MUST keep CSRF.

```ruby
# Safe: Token-only API
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_token

  private

  def authenticate_api_token
    token = request.headers["Authorization"]&.remove("Bearer ")
    @current_api_user = ApiToken.find_by(token: token)&.user
    head :unauthorized unless @current_api_user
  end
end
```
