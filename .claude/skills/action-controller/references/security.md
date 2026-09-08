# Security — rescue_from, CSRF, HTTP Auth, CSP, and More

Error handling, CSRF protection, authentication, content security policy, and other security features.

## rescue_from Patterns

### Order matters — most specific first

```ruby
class ApplicationController < ActionController::Base
  # Most specific first
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  # ⚠️ NEVER do this — breaks Rails internals:
  # rescue_from Exception, with: :handle_all
  # rescue_from StandardError, with: :handle_all
end
```

### Handler receives the exception

```ruby
rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

private
  def unprocessable(exception)
    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end
```

### Block syntax

```ruby
rescue_from ActiveRecord::RecordNotFound do |exception|
  render json: { error: exception.message }, status: :not_found
end
```

### Format-aware handlers

```ruby
def not_found
  respond_to do |format|
    format.html { render "errors/not_found", status: :not_found }
    format.json { render json: { error: "Not found" }, status: :not_found }
    format.any  { head :not_found }
  end
end
```

### Custom exception classes

```ruby
# app/errors/authorization_error.rb
class AuthorizationError < StandardError; end

# In controller
class ApplicationController < ActionController::Base
  rescue_from AuthorizationError do
    redirect_back fallback_location: root_path, alert: "Access denied."
  end
end

# Raise it
def update
  raise AuthorizationError unless current_user.can_edit?(@post)
  # ...
end
```

---

## CSRF Protection Details

### How it works

1. Rails generates an authenticity token for each session
2. The token is embedded in forms (via `form_with`) and in a `<meta>` tag
3. On non-GET requests, Rails verifies the submitted token matches the session's token
4. Mismatch → `ActionController::InvalidAuthenticityToken` (or session reset)

### Configuration

```ruby
class ApplicationController < ActionController::Base
  # Default — raises exception
  protect_from_forgery with: :exception

  # Alternative — just resets session (less disruptive)
  protect_from_forgery with: :reset_session

  # Null session — useful for APIs that may receive cookies
  protect_from_forgery with: :null_session
end
```

### Skipping for APIs

```ruby
# Option 1: Skip in specific controller
class Api::V1::BaseController < ApplicationController
  skip_forgery_protection
end

# Option 2: Inherit from API base (better)
class Api::V1::BaseController < ActionController::API
  # No CSRF protection included by default
end
```

### Custom AJAX with CSRF

If you're making fetch/XHR calls that don't use Turbo or rails-ujs, include the token manually:

```javascript
// Read from meta tag
const token = document.querySelector('meta[name="csrf-token"]').content;

fetch('/posts', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': token
  },
  body: JSON.stringify({ post: { title: 'Hi' } })
});
```

### Authenticity token in meta tag

```erb
<!-- In layout head -->
<%= csrf_meta_tags %>
<!-- Renders: -->
<!-- <meta name="csrf-token" content="..."> -->
<!-- <meta name="csrf-param" content="authenticity_token"> -->
```

---

## HTTP Authentication

### Basic Auth

```ruby
# Class-level (simplest)
class AdminController < ApplicationController
  http_basic_authenticate_with name: "admin", password: ENV["ADMIN_PW"]
end

# Method-level (more control)
class AdminController < ApplicationController
  before_action :authenticate

  private
    def authenticate
      authenticate_or_request_with_http_basic("Admin") do |name, password|
        ActiveSupport::SecurityUtils.secure_compare(name, "admin") &
          ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PW"])
      end
    end
end
```

Always use `secure_compare` to prevent timing attacks.

### Digest Auth

```ruby
class AdminController < ApplicationController
  USERS = { "admin" => Digest::MD5.hexdigest("admin:realm:password") }

  before_action :authenticate

  private
    def authenticate
      authenticate_or_request_with_http_digest("Application") do |username|
        USERS[username]
      end
    end
end
```

### Token Auth

```ruby
class Api::BaseController < ActionController::API
  before_action :authenticate

  private
    def authenticate
      authenticate_or_request_with_http_token do |token, _options|
        @current_user = User.find_by(api_token: token)
      end
    end
end
```

Client sends: `Authorization: Token token="abc123"`

---

## Log Filtering

### Filter sensitive params from logs

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :credit_card, :card_number
]
```

Uses partial matching — `:passw` filters `password`, `password_confirmation`, etc.

### Filter redirect URLs

```ruby
# config/application.rb
config.filter_redirect << "s3.amazonaws.com"
config.filter_redirect << /private_path/
```

---

## Force SSL

```ruby
# config/environments/production.rb
config.force_ssl = true
```

This enables the `ActionDispatch::SSL` middleware which:
- Redirects HTTP to HTTPS
- Sets `Strict-Transport-Security` header
- Marks cookies as secure

---

## Content Security Policy

Rails has built-in CSP support:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline

    # Nonce for inline scripts (works with Turbo)
    policy.script_src  :self, :https, :strict_dynamic
  end

  # Generate nonce for script tags
  config.content_security_policy_nonce_generator = ->(request) {
    request.session.id.to_s
  }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
```

Per-controller override:

```ruby
class AdminController < ApplicationController
  content_security_policy do |policy|
    policy.script_src :self, :unsafe_eval  # needed for some admin tools
  end
end

# Disable for specific actions
content_security_policy false, only: :legacy_page
```

---

## Browser Version Control

Rails 7.2+ includes `allow_browser` for blocking outdated browsers:

```ruby
class ApplicationController < ActionController::Base
  # Block anything older than Safari 17.2, Chrome 120, Firefox 121, Opera 106
  allow_browser versions: :modern
end

# Custom versions
class ApplicationController < ActionController::Base
  allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
  # ie: false blocks ALL IE versions
  # Unlisted browsers (Chrome, Opera) are allowed
end

# Per-action
class MessagesController < ApplicationController
  allow_browser versions: { opera: 104, chrome: 119 }, only: :show
end
```

Blocked browsers get `public/406-unsupported-browser.html` with 406 status.
