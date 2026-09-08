# Configuration and Edge Cases

Edge cases, gotchas, and production recipes for Action Mailer.

---

## Edge Cases and Gotchas

### 1. params is nil Without .with()

```ruby
# This WILL blow up if you access params[:user]
UserMailer.welcome_email.deliver_later  # WRONG

# Always use .with()
UserMailer.with(user: @user).welcome_email.deliver_later  # CORRECT
```

### 2. deliver_later Serializes Arguments

Active Job serializes params for `deliver_later`. This means:
- ActiveRecord objects are serialized by class + ID and re-fetched at delivery time
- If the record is deleted between enqueue and delivery, you get `ActiveJob::DeserializationError`
- Non-serializable objects (Procs, IO) cannot be passed via params

```ruby
# WRONG — Proc can't be serialized
UserMailer.with(user: @user, callback: -> { do_something }).action.deliver_later

# CORRECT — Pass only serializable data
UserMailer.with(user: @user, callback_type: "signup").action.deliver_later
```

### 3. Template Lookup Order

Action Mailer looks for templates in:
1. `app/views/{mailer_name}/{action_name}.{format}.erb`
2. Custom `template_path` if specified
3. `prepend_view_path` directories

### 4. Multipart Email Part Order

The order of parts in multipart emails is determined by `:parts_order` in defaults:

```ruby
class ApplicationMailer < ActionMailer::Base
  default parts_order: ["text/plain", "text/html"]
end
```

### 5. Email with No Recipients is Silently Skipped

```ruby
mail(to: nil, subject: "Test")  # No error, no email sent
mail(to: [], subject: "Test")   # No error, no email sent
```

### 6. Headers Method vs mail() Options

```ruby
# Both work — use mail() options for standard headers
mail(to: "user@example.com", subject: "Hi")

# Use headers() for custom/non-standard headers
headers["X-Custom-Header"] = "value"
headers["List-Unsubscribe"] = "<mailto:unsubscribe@example.com>"
```

### 7. Mailer Method Names

Mailer method names don't need to end in `_email`. Any public method works:

```ruby
class UserMailer < ApplicationMailer
  def welcome        # Fine
  def welcome_email  # Also fine
  def notify         # Also fine
end
```

### 8. Caching in Mailer Views

```ruby
# Enable in environment config
config.action_mailer.perform_caching = true
```

```html+erb
<%# Then use cache helper in views %>
<% cache @user do %>
  <h1>Hello, <%= @user.name %></h1>
<% end %>
```

---

## Production Recipes

### Unsubscribe Header

```ruby
class MarketingMailer < ApplicationMailer
  after_action :add_unsubscribe_header

  private

  def add_unsubscribe_header
    headers["List-Unsubscribe"] = "<#{unsubscribe_url(token: @user.unsubscribe_token)}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end
end
```

### Conditional Delivery (Preferences)

```ruby
class NotificationMailer < ApplicationMailer
  before_deliver :check_preferences

  def activity_update
    @user = params[:user]
    @activity = params[:activity]
    mail(to: @user.email, subject: "New activity")
  end

  private

  def check_preferences
    throw :abort unless params[:user].email_notifications_enabled?
  end
end
```

### Rate-Limited Delivery

```ruby
class DigestMailer < ApplicationMailer
  before_deliver :rate_limit

  def weekly_digest
    @user = params[:user]
    mail(to: @user.email, subject: "Your Weekly Digest")
  end

  private

  def rate_limit
    last_sent = EmailLog.where(
      mailer: self.class.name,
      action: action_name,
      recipient: params[:user].email
    ).maximum(:sent_at)

    throw :abort if last_sent && last_sent > 6.days.ago
  end
end
```

### Multi-Tenant SMTP

```ruby
class TenantMailer < ApplicationMailer
  after_action :set_tenant_smtp

  private

  def set_tenant_smtp
    tenant = params[:tenant]
    if tenant&.custom_smtp?
      mail.delivery_method.settings.merge!(
        address:   tenant.smtp_address,
        port:      tenant.smtp_port,
        user_name: tenant.smtp_username,
        password:  tenant.smtp_password
      )
    end
  end
end
```

### Premailer for Inline CSS

```ruby
# Gemfile
gem "premailer-rails"

# That's it — premailer-rails automatically inlines CSS from <style> tags
# and linked stylesheets in your mailer layouts before sending.
```
