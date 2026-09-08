# Advanced Security Threats

## Redirect Security

### url_from (Rails 7+)

```ruby
# url_from returns nil if the URL doesn't point to your app
redirect_to url_from(params[:return_to]) || root_path

# It checks: same host, same port, same protocol
url_from("https://myapp.com/dashboard")    # => "https://myapp.com/dashboard"
url_from("https://evil.com/phishing")      # => nil
url_from("javascript:alert(1)")            # => nil
```

### Manual Validation

```ruby
def safe_redirect_path(path)
  return root_path if path.blank?

  uri = URI.parse(path.to_s)
  # Only allow relative paths starting with /
  if uri.relative? && uri.path.start_with?("/") && !uri.path.start_with?("//")
    uri.path
  else
    root_path
  end
rescue URI::InvalidURIError
  root_path
end
```

### Open Redirect via Host Parameter

```ruby
# DANGEROUS — Rails redirect_to with hash can be exploited
redirect_to params.update(action: "show")
# Attacker adds ?host=evil.com → redirects to evil.com

# SAFE — never pass raw params to redirect_to with update/merge
redirect_to action: "show"
```

## Command Injection

### system() and Friends

```ruby
# DANGEROUS — shell injection via semicolons, pipes, backticks
system("convert #{params[:filename]} output.png")
# Attacker: "image.png; rm -rf /"

# SAFE — pass arguments as array (no shell interpretation)
system("convert", params[:filename], "output.png")

# DANGEROUS
`echo #{user_input}`
exec("ls #{user_input}")

# SAFE
IO.popen(["echo", user_input]) { |io| io.read }
```

### Kernel#open

```ruby
# DANGEROUS — Kernel#open executes commands with pipe prefix
open("| rm -rf /")  # Executes the command!
open(params[:url])   # If user sends "| malicious_command"

# SAFE alternatives
File.open(path)
URI.open(url)       # For URLs (requires 'open-uri')
IO.open(fd)
```

## CORS Configuration

```ruby
# Only needed if your frontend is on a different origin

# Gemfile
gem "rack-cors"

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://app.example.com"  # Be specific!

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400
  end
end

# WRONG — allows any origin (defeats same-origin policy)
origins "*"  # NEVER use with credentials: true
```

## Rate Limiting

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
end

class PasswordsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create
end

class Api::BaseController < ApplicationController
  rate_limit to: 100, within: 1.minute
end
```

## Regex Security in Ruby

```ruby
# Ruby's ^ and $ match LINE boundaries, not string boundaries
# This is a common security bug in format validators

# VULNERABLE
/^https?:\/\/[^\n]+$/
# Bypassed by: "javascript:alert(1)\nhttp://legit.com"

# SECURE
/\Ahttps?:\/\/[^\n]+\z/

# Rails validates_format_of raises if you use ^ or $
# unless you set multiline: true (acknowledging the risk)
validates :url, format: { with: /\Ahttps:\/\//, message: "must be HTTPS" }
```

## DNS Rebinding Protection

```ruby
# config/environments/production.rb
Rails.application.config.hosts << "myapp.com"
Rails.application.config.hosts << ".myapp.com"  # Allows subdomains

# Exclude health checks
Rails.application.config.host_authorization = {
  exclude: ->(request) { request.path.include?("/healthcheck") }
}
```

## Logging and Error Handling

### Filter Sensitive Parameters

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt,
  :certificate, :otp, :ssn, :credit_card, :cvv,
  :authorization, :api_key
]
```

### Don't Leak Stack Traces

```ruby
# config/environments/production.rb
config.consider_all_requests_local = false  # Default — don't change!
# Shows generic error page, not stack traces

# Custom error pages
# app/views/errors/internal_server_error.html.erb
# app/views/errors/not_found.html.erb
```

### Rescue Handlers

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionPolicy::Unauthorized, with: :forbidden

  private

  def not_found
    render "errors/not_found", status: :not_found
  end

  def forbidden
    render "errors/forbidden", status: :forbidden
  end
end

# NEVER expose detailed errors to users:
# WRONG
rescue => e
  render json: { error: e.message, backtrace: e.backtrace }

# CORRECT
rescue => e
  Rails.logger.error("Payment failed: #{e.message}")
  render json: { error: "Payment processing failed. Please try again." }, status: 500
end
```
