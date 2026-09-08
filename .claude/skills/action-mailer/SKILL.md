---
name: action-mailer
description: Expert guidance for Action Mailer in Rails applications. Use when creating mailers, sending emails, building email templates, configuring delivery, writing mailer previews, or working with transactional email. Triggers on "mailer", "email", "send email", "action mailer", "mail template", "deliver_later", "email notification", "transactional email", "mailer preview", "welcome email", "notification email".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate mailer*), Bash(bin/rails test*), Bash(bundle exec rails test*)
---

# Rails Action Mailer Expert

Create, configure, and deliver emails from Rails applications using Action Mailer.

## Philosophy

**Core Principles:**
1. **Default to `deliver_later`** — Queues emails via Active Job. `deliver_now` blocks the HTTP request, making users wait for SMTP round-trips.
2. **Create both HTML and text templates** — Some email clients block HTML, and spam filters penalize HTML-only emails. Always provide a text fallback.
3. **Use parameterized mailers** — Pass context via `with()`, not method arguments. This makes callbacks and shared setup work cleanly.
4. **Set `default from:`** — Every mailer needs a default sender. Without it, emails fail silently or get rejected by mail servers.
5. **Write previews** — Preview classes let you iterate on email design without sending real emails or writing test data by hand.
6. **Use `_url` helpers, not `_path`** — Emails have no request context, so relative paths produce broken links. `_url` generates absolute URLs.

## When To Use This Skill

- Generating new mailer classes
- Creating email templates (HTML + text)
- Configuring SMTP/delivery settings
- Adding attachments or inline images
- Writing mailer previews and tests
- Setting up interceptors or observers
- Implementing I18n for email subjects
- Debugging email delivery issues

## Instructions

### Step 1: Check Existing Mailer Patterns

**Check the project first** — match existing mailer patterns for consistency:

```bash
# Find existing mailers
ls app/mailers/

# Check ApplicationMailer defaults
cat app/mailers/application_mailer.rb

# Find existing templates
ls app/views/layouts/mailer.*
find app/views -name "*.html.erb" -path "*/mailer*" -o -name "*.text.erb" -path "*/mailer*"

# Check delivery config
grep -r "action_mailer" config/environments/

# Find existing previews
ls test/mailers/previews/
```

**Consistency with the existing codebase matters more than theoretical best practice.**

### Step 2: Generate or Create the Mailer

**Use the generator with action names:**

```bash
bin/rails generate mailer User welcome_email password_reset
```

This creates:
- `app/mailers/user_mailer.rb` — Mailer class
- `app/views/user_mailer/welcome_email.html.erb` — HTML template
- `app/views/user_mailer/welcome_email.text.erb` — Text template
- `app/views/user_mailer/password_reset.html.erb`
- `app/views/user_mailer/password_reset.text.erb`
- `test/mailers/user_mailer_test.rb` — Test file
- `test/mailers/previews/user_mailer_preview.rb` — Preview class

**If ApplicationMailer doesn't exist, create it:**

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "notifications@example.com"
  layout "mailer"
end
```

### Step 3: Write the Mailer Class

**Use parameterized mailers (with/params pattern):**

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: "notifications@example.com"

  def welcome_email
    @user = params[:user]
    @login_url = login_url
    mail(
      to: email_address_with_name(@user.email, @user.name),
      subject: "Welcome to #{app_name}"
    )
  end

  def password_reset
    @user = params[:user]
    @token = params[:token]
    @reset_url = edit_password_reset_url(token: @token)
    mail(to: @user.email, subject: "Reset your password")
  end

  private

  def app_name
    Rails.application.class.module_parent_name
  end
end
```

**Calling the mailer — prefer `deliver_later`:**

```ruby
# Preferred — async via Active Job (user doesn't wait for SMTP)
UserMailer.with(user: @user).welcome_email.deliver_later

# With params
UserMailer.with(user: @user, token: @token).password_reset.deliver_later

# Synchronous — blocks the request while talking to SMTP server
UserMailer.with(user: @user).welcome_email.deliver_now
```

**Only use `deliver_now` for:** rake tasks/cron jobs, console debugging, or critical emails needing immediate confirmation.

### Step 4: Create BOTH Templates

**Create both HTML and text versions.** Action Mailer auto-generates `multipart/alternative` emails when both exist.

**HTML template** (`app/views/user_mailer/welcome_email.html.erb`):

```html+erb
<h1>Welcome, <%= @user.name %>!</h1>

<p>Thanks for signing up. Your account is ready.</p>

<p>
  <%= link_to "Log in to your account", @login_url %>
</p>
```

**Text template** (`app/views/user_mailer/welcome_email.text.erb`):

```erb
Welcome, <%= @user.name %>!

Thanks for signing up. Your account is ready.

Log in: <%= @login_url %>
```

**Why both?** Some email clients block HTML. Spam filters penalize HTML-only emails. Text fallback is a deliverability requirement.

### Step 5: Configure URL Host

**Emails need absolute URLs** because there's no browser request context to resolve relative paths against:

```ruby
# config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

# config/environments/production.rb
config.action_mailer.default_url_options = { host: "www.example.com", protocol: "https" }
```

**In templates, use `_url` helpers:**

```erb
<%# CORRECT %>
<%= link_to "View order", order_url(@order) %>

<%# WRONG — will break in email %>
<%= link_to "View order", order_path(@order) %>
```

### Step 6: Write Mailer Previews

**Write a preview for each mailer action** — this lets you iterate on design at `/rails/mailers` without sending real emails:

```ruby
# test/mailers/previews/user_mailer_preview.rb
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.first || User.new(name: "Preview User", email: "preview@example.com")
    UserMailer.with(user: user).welcome_email
  end

  def password_reset
    user = User.first || User.new(name: "Preview User", email: "preview@example.com")
    UserMailer.with(user: user, token: "preview-token-123").password_reset
  end
end
```

**Preview tips:**
- Use `User.first` with a fallback `User.new(...)` so previews work even with empty DB
- Just return the mail object — don't call `deliver_later` in previews
- Previews auto-reload on template changes

### Step 7: Write Mailer Tests

```ruby
# test/mailers/user_mailer_test.rb
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome_email" do
    user = users(:active_user)
    email = UserMailer.with(user: user).welcome_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["notifications@example.com"], email.from
    assert_equal [user.email], email.to
    assert_equal "Welcome to MyApp", email.subject

    # Test HTML part
    assert_match user.name, email.html_part.body.to_s
    assert_match "Log in", email.html_part.body.to_s

    # Test text part
    assert_match user.name, email.text_part.body.to_s
  end
end
```

**Key test assertions:**

```ruby
# Count emails sent
assert_emails 1 do
  UserMailer.with(user: user).welcome_email.deliver_now
end

# No emails sent
assert_no_emails do
  # action that shouldn't send email
end

# Enqueued for later delivery
assert_enqueued_emails 1 do
  UserMailer.with(user: user).welcome_email.deliver_later
end

# Check email content
assert_equal ["to@example.com"], email.to
assert_equal ["from@example.com"], email.from
assert_equal "Subject", email.subject
assert_match "expected text", email.body.encoded
```

### Step 8: Configure Delivery Method

**Development — use letter_opener or :test:**

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener # Opens in browser
# OR
config.action_mailer.delivery_method = :test # Stores in ActionMailer::Base.deliveries
```

**Production — SMTP:**

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:         "smtp.example.com",
  port:            587,
  domain:          "example.com",
  user_name:       Rails.application.credentials.dig(:smtp, :user_name),
  password:        Rails.application.credentials.dig(:smtp, :password),
  authentication:  "plain",
  enable_starttls: true,
  open_timeout:    5,
  read_timeout:    5
}
```

**Test — always `:test`:**

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method = :test
```

## Quick Reference

### mail() Method Options

| Option | Description |
|--------|-------------|
| `to:` | Recipient(s) — string or array |
| `from:` | Sender (overrides default) |
| `cc:` | Carbon copy recipients |
| `bcc:` | Blind carbon copy recipients |
| `reply_to:` | Reply-to address |
| `subject:` | Email subject line |
| `headers:` | Custom headers hash |
| `template_path:` | Custom view directory |
| `template_name:` | Custom template name |
| `delivery_method_options:` | Per-email delivery overrides |

### Attachments

```ruby
def invoice_email
  @invoice = params[:invoice]

  # Simple attachment
  attachments["invoice.pdf"] = File.read("/path/to/invoice.pdf")

  # Attachment with options
  attachments["report.csv"] = {
    mime_type: "text/csv",
    content: generate_csv_data
  }

  mail(to: @invoice.customer_email, subject: "Your Invoice")
end
```

### Inline Attachments (Images in Email Body)

```ruby
# In mailer
def newsletter
  attachments.inline["logo.png"] = File.read("app/assets/images/logo.png")
  mail(to: params[:user].email, subject: "Newsletter")
end
```

```html+erb
<%# In HTML template %>
<%= image_tag attachments["logo.png"].url, alt: "Company Logo" %>
```

### Callbacks

```ruby
class ApplicationMailer < ActionMailer::Base
  before_action :set_default_vars
  after_action  :log_delivery
  after_deliver :record_sent

  private

  def set_default_vars
    @company_name = "MyApp"
  end

  def log_delivery
    Rails.logger.info("Preparing email: #{action_name}")
  end

  def record_sent
    # Called after successful delivery
    EmailLog.create!(mailer: self.class.name, action: action_name)
  end
end
```

### Interceptors and Observers

```ruby
# config/initializers/mail_interceptors.rb
Rails.application.configure do
  if Rails.env.staging?
    config.action_mailer.interceptors = %w[SandboxEmailInterceptor]
  end
  config.action_mailer.observers = %w[EmailDeliveryObserver]
end

# app/interceptors/sandbox_email_interceptor.rb
class SandboxEmailInterceptor
  def self.delivering_email(message)
    message.to = ["sandbox@example.com"]
  end
end

# app/observers/email_delivery_observer.rb
class EmailDeliveryObserver
  def self.delivered_email(message)
    EmailDelivery.log(message)
  end
end
```

### rescue_from in Mailers

```ruby
class NotifierMailer < ApplicationMailer
  rescue_from ActiveJob::DeserializationError do |exception|
    # Handle stale records gracefully
  end

  rescue_from Net::SMTPAuthenticationError do |exception|
    # Handle SMTP auth failures
  end
end
```

### I18n for Email Subjects

```yaml
# config/locales/en.yml
en:
  user_mailer:
    welcome_email:
      subject: "Welcome to %{app_name}"
    password_reset:
      subject: "Reset your password"
```

```ruby
# Mailer — omit subject: to auto-lookup from I18n
def welcome_email
  @user = params[:user]
  mail(to: @user.email) # Subject from en.user_mailer.welcome_email.subject
end
```

### Parameterized Mailers for Shared Context

Use `before_action` + `params` to share context across multiple actions:

```ruby
class InvitationsMailer < ApplicationMailer
  before_action { @inviter = params[:inviter]; @invitee = params[:invitee] }

  default to:   -> { @invitee.email },
          from: -> { email_address_with_name("invites@example.com", @inviter.name) }

  def account_invitation
    mail subject: "#{@inviter.name} invited you to #{params[:inviter].account.name}"
  end
end

# Call with: InvitationsMailer.with(inviter: user, invitee: other).account_invitation.deliver_later
```

## Detailed References

For deeper patterns and examples, see the `references/` directory:
- `references/templates.md` — Mailer class patterns, HTML/text templates, attachments, I18n, layouts
- `references/delivery.md` — SMTP configuration, per-environment setup, error handling
- `references/testing.md` — Mailer test patterns, delivery assertions, integration tests
- `references/interceptors.md` — Callbacks, interceptors, observers, delivery lifecycle
- `references/previews.md` — Preview classes, fallback data, custom preview paths
- `references/configuration.md` — Edge cases, gotchas, production recipes

## Common Agent Mistakes

1. **Using `deliver_now` instead of `deliver_later`** — Blocks the HTTP request while waiting for SMTP; users experience slow page loads
2. **Creating only HTML template** — Spam filters penalize HTML-only emails, and some clients block HTML entirely
3. **Missing `default from:` address** — Mail servers reject emails without a sender, often silently
4. **Using `_path` helpers in templates** — Produces relative URLs that break in email clients (no request context to resolve against)
5. **Passing args instead of using `with()`** — Parameterized mailers (`Mailer.with(user: @user).action`) work cleanly with callbacks and shared setup
6. **Forgetting to set `default_url_options`** — `_url` helpers raise errors or produce `localhost` links in production without host config
7. **Not writing previews** — Without previews, you're sending real emails or writing tests just to see what an email looks like
8. **Not configuring delivery method per environment** — `:test` for test, `:letter_opener` for dev, `:smtp` for prod

## Anti-Patterns to Avoid

1. **Fat mailers** — Keep business logic in models/services. Mailers should just assemble and send; logic in mailers is hard to test and reuse
2. **Inline styles in templates** — Use a mailer layout with shared styles; consider `premailer-rails` to auto-inline CSS for email client compatibility
3. **Hardcoded URLs** — Route helpers with `_url` suffix stay correct when routes change; hardcoded strings rot
4. **No text fallback** — HTML-only emails hurt deliverability scores and are inaccessible to screen readers
5. **Synchronous delivery in controllers** — `deliver_now` in a request makes users wait for SMTP round-trips
6. **Untested mailers** — Test content, recipients, subject, and delivery count
7. **Secrets in mailer views** — Never expose tokens/passwords in emails; use short-lived, hashed links instead

## File Structure

```
app/
  mailers/
    application_mailer.rb          # Base class — default from, layout
    user_mailer.rb                 # Mailer class
  views/
    layouts/
      mailer.html.erb              # HTML layout (wraps all mailer HTML views)
      mailer.text.erb              # Text layout
    user_mailer/
      welcome_email.html.erb       # HTML template
      welcome_email.text.erb       # Text template
config/
  environments/
    development.rb                 # delivery_method, default_url_options
    production.rb                  # SMTP settings
    test.rb                        # delivery_method: :test
test/
  mailers/
    user_mailer_test.rb            # Mailer tests
    previews/
      user_mailer_preview.rb       # Email previews
```
