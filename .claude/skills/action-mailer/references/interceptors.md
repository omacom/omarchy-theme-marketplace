# Interceptors and Observers

Global email interception, observation, and callback patterns.

---

## Callbacks In Depth

### Callback Order

When sending an email, callbacks fire in this order:

1. `before_action` — Set up instance vars, populate defaults
2. **Mailer action executes** — Your method runs
3. `after_action` — Modify message, set headers
4. `before_deliver` — Last chance to modify or abort
5. **Email delivered**
6. `after_deliver` — Log, record, notify

### before_action — Shared Setup

```ruby
class InvitationsMailer < ApplicationMailer
  before_action :set_inviter_and_invitee
  before_action { @account = params[:inviter].account }

  default to:       -> { @invitee.email },
          from:     -> { email_address_with_name("invites@example.com", @inviter.name) },
          reply_to: -> { @inviter.email }

  def account_invitation
    mail(subject: "#{@inviter.name} invited you to #{@account.name}")
  end

  private

  def set_inviter_and_invitee
    @inviter = params[:inviter]
    @invitee = params[:invitee]
  end
end
```

### after_action — Modify Before Delivery

```ruby
class UserMailer < ApplicationMailer
  after_action :set_delivery_options
  after_action :prevent_delivery_to_guests
  after_action :set_custom_headers

  def feedback_message
    @feedback = params[:feedback]
    @user = params[:user]
    mail(to: @user.email, subject: "Feedback received")
  end

  private

  def set_delivery_options
    if @business&.has_smtp_settings?
      mail.delivery_method.settings.merge!(@business.smtp_settings)
    end
  end

  def prevent_delivery_to_guests
    mail.perform_deliveries = false if @user&.guest?
  end

  def set_custom_headers
    headers["X-Mailer-Category"] = action_name
    headers["X-App-Version"] = Rails.application.config.version
  end
end
```

### before_deliver — Intercept/Abort

```ruby
class ApplicationMailer < ActionMailer::Base
  before_deliver :sandbox_staging

  private

  def sandbox_staging
    if Rails.env.staging?
      message.to = ["staging-inbox@example.com"]
      message.subject = "[STAGING] #{message.subject}"
    end
  end
end
```

Abort delivery with `throw :abort`:

```ruby
before_deliver :check_recipient_preferences

def check_recipient_preferences
  throw :abort if recipient_unsubscribed?
end
```

### after_deliver — Post-Delivery Actions

```ruby
class NotificationMailer < ApplicationMailer
  after_deliver :log_delivery
  after_deliver :update_notification_status

  def notify
    @notification = params[:notification]
    mail(to: @notification.user.email, subject: @notification.subject)
  end

  private

  def log_delivery
    EmailLog.create!(
      mailer: self.class.name,
      action: action_name,
      recipient: message.to.first,
      subject: message.subject,
      sent_at: Time.current
    )
  end

  def update_notification_status
    params[:notification].update!(emailed_at: Time.current)
  end
end
```

### Aborting on Body Set

Mailer callbacks abort further processing if `body` is set to a non-nil value. This means if a `before_action` sets the body, the mailer action won't run its template rendering.

---

## Email Interceptor — Modify Before Sending

Interceptors run before the email is handed to the delivery agent:

```ruby
# app/interceptors/sandbox_email_interceptor.rb
class SandboxEmailInterceptor
  def self.delivering_email(message)
    message.to = ["sandbox@example.com"]
    message.cc = nil
    message.bcc = nil
    message.subject = "[SANDBOX] #{message.subject}"
  end
end
```

## Email Observer — React After Sending

Observers run after successful delivery:

```ruby
# app/observers/email_delivery_observer.rb
class EmailDeliveryObserver
  def self.delivered_email(message)
    EmailDelivery.create!(
      to: message.to&.join(", "),
      from: message.from&.join(", "),
      subject: message.subject,
      message_id: message.message_id,
      delivered_at: Time.current
    )
  end
end
```

## Registration

```ruby
# config/initializers/mail_interceptors.rb
Rails.application.configure do
  if Rails.env.staging?
    config.action_mailer.interceptors = %w[SandboxEmailInterceptor]
  end

  config.action_mailer.observers = %w[EmailDeliveryObserver]
end
```

## When to Use Callbacks vs Interceptors

| Feature | Callbacks | Interceptors/Observers |
|---------|-----------|----------------------|
| Scope | Per-mailer class | All mailers globally |
| Access to mailer context | Yes (params, instance vars) | No (only `Mail::Message`) |
| Can abort delivery | Yes (`throw :abort`) | Yes (set `perform_deliveries = false`) |
| Registration | In mailer class | In initializer |

**Use callbacks** when logic is specific to a mailer. **Use interceptors/observers** for global concerns (sandboxing, logging, analytics).
