# Delivery Configuration

SMTP settings, environment-specific delivery methods, and per-email overrides.

---

## SMTP (Production)

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
config.action_mailer.default_url_options = { host: "www.example.com", protocol: "https" }
config.action_mailer.asset_host = "https://www.example.com"
```

## Gmail SMTP

```ruby
config.action_mailer.smtp_settings = {
  address:         "smtp.gmail.com",
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

## Sendmail

```ruby
config.action_mailer.delivery_method = :sendmail
config.action_mailer.sendmail_settings = {
  location:  "/usr/sbin/sendmail",
  arguments: %w[-i]
}
```

## Development — Letter Opener

```ruby
# Gemfile
gem "letter_opener", group: :development

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

## Test Environment

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method = :test
config.action_mailer.default_url_options = { host: "www.example.com" }
```

## Per-Email Delivery Overrides

```ruby
def welcome_email
  @user = params[:user]
  delivery_options = {
    user_name: params[:company].smtp_user,
    password:  params[:company].smtp_password,
    address:   params[:company].smtp_host
  }
  mail(
    to: @user.email,
    subject: "Welcome",
    delivery_method_options: delivery_options
  )
end
```

## Key Configuration Options

```ruby
# Raise errors if delivery fails (recommended in development)
config.action_mailer.raise_delivery_errors = true

# Actually send emails (set false to suppress all delivery)
config.action_mailer.perform_deliveries = true

# Enable caching in mailer views
config.action_mailer.perform_caching = true

# Queue name for deliver_later jobs
config.action_mailer.deliver_later_queue_name = :mailers

# Default from address (app-wide fallback)
config.action_mailer.default_options = { from: "noreply@example.com" }
```

## Error Handling

### rescue_from in Mailers

```ruby
class ApplicationMailer < ActionMailer::Base
  rescue_from ActiveJob::DeserializationError do |exception|
    Rails.logger.warn("Mailer deserialization error: #{exception.message}")
    # Record was deleted between enqueue and delivery — skip silently
  end

  rescue_from Net::SMTPAuthenticationError do |exception|
    Rails.logger.error("SMTP auth failed: #{exception.message}")
    ErrorNotifier.notify(exception)
  end

  rescue_from Net::SMTPServerBusy do |exception|
    Rails.logger.warn("SMTP busy: #{exception.message}")
    # Active Job will retry automatically
    raise # Re-raise to trigger retry
  end
end
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ActionView::MissingTemplate` | No template file for mailer action | Create both `.html.erb` and `.text.erb` |
| `ArgumentError: missing host` | `default_url_options` not set | Add `config.action_mailer.default_url_options` |
| `Net::SMTPAuthenticationError` | Bad SMTP credentials | Check credentials in `rails credentials:edit` |
| `ActiveJob::DeserializationError` | Record deleted between enqueue and delivery | Add `rescue_from` in mailer |
| `NoMethodError` on `params` | Called mailer without `.with()` | Use `UserMailer.with(user: @user).action` |
