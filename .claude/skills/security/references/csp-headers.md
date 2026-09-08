# Content Security Policy Deep Dive

## Starter Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https
  policy.connect_src :self, :https
  policy.frame_ancestors :none
  policy.base_uri    :self
  policy.form_action :self
end
```

## Nonce-Based CSP (Recommended over 'unsafe-inline')

```ruby
# Generate nonce per request
Rails.application.config.content_security_policy_nonce_generator =
  ->(request) { SecureRandom.base64(16) }

# Apply to script-src (and optionally style-src)
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
```

```erb
<!-- Tags automatically get nonce attribute -->
<%= javascript_include_tag "application", nonce: true %>
<%= javascript_tag nonce: true do %>
  console.log("This is allowed by CSP");
<% end %>
```

## Per-Controller Overrides

```ruby
class PaymentsController < ApplicationController
  content_security_policy do |policy|
    policy.script_src :self, "https://js.stripe.com"
    policy.frame_src "https://js.stripe.com"
  end
end
```

## Report-Only Mode for Migration

```ruby
# Start with report-only to find violations without breaking your app
Rails.application.config.content_security_policy_report_only = true
```
