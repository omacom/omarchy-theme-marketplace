# Action Mailbox Reference

Detailed patterns, provider configurations, edge cases, and advanced usage for Action Mailbox in Rails.

## Table of Contents
- [Ingress Provider Configuration](#ingress-provider-configuration)
- [Advanced Routing Patterns](#advanced-routing-patterns)
- [Working with Email Content](#working-with-email-content)
- [Callbacks In Depth](#callbacks-in-depth)
- [Testing Patterns](#testing-patterns)
- [Error Handling Patterns](#error-handling-patterns)
- [Incineration Details](#incineration-details)
- [Production Checklist](#production-checklist)
- [Common Gotchas](#common-gotchas)
- [Useful Gems](#useful-gems)
- [Rails Console Recipes](#rails-console-recipes)

## Ingress Provider Configuration

### Mailgun

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :mailgun
```

**Credentials:**
```yaml
# credentials.yml.enc
action_mailbox:
  mailgun_signing_key: "key-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```
Or: `MAILGUN_INGRESS_SIGNING_KEY` env var.

**Mailgun dashboard setup:**
1. Go to Receiving → Create Route
2. Expression type: Match Recipient
3. Pattern: your target addresses (e.g., `.*@mail.example.com`)
4. Action: Forward to `https://example.com/rails/action_mailbox/mailgun/inbound_emails/mime`
5. Priority: 0

**Endpoint:** `/rails/action_mailbox/mailgun/inbound_emails/mime`

---

### SendGrid

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :sendgrid
```

**Credentials:**
```yaml
# credentials.yml.enc
action_mailbox:
  ingress_password: "strong-random-password"
```
Or: `RAILS_INBOUND_EMAIL_PASSWORD` env var.

**SendGrid Inbound Parse setup:**
1. Settings → Inbound Parse → Add Host & URL
2. URL: `https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/sendgrid/inbound_emails`
3. **Check "Post the raw, full MIME message"** ← Critical! Action Mailbox needs the raw MIME.
4. Domain/hostname: your receiving domain

**Endpoint:** `/rails/action_mailbox/sendgrid/inbound_emails`  
**Auth:** HTTP Basic (`actionmailbox:PASSWORD`)

---

### Postmark

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :postmark
```

**Credentials:**
```yaml
# credentials.yml.enc
action_mailbox:
  ingress_password: "strong-random-password"
```
Or: `RAILS_INBOUND_EMAIL_PASSWORD` env var.

**Postmark setup:**
1. Servers → your server → Settings → Inbound
2. Webhook URL: `https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/postmark/inbound_emails`
3. **Check "Include raw email content in JSON payload"** ← Critical!

**Endpoint:** `/rails/action_mailbox/postmark/inbound_emails`  
**Auth:** HTTP Basic (`actionmailbox:PASSWORD`)

---

### Mandrill (Mailchimp Transactional)

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :mandrill
```

**Credentials:**
```yaml
# credentials.yml.enc
action_mailbox:
  mandrill_api_key: "your-mandrill-api-key"
```
Or: `MANDRILL_INGRESS_API_KEY` env var.

**Mandrill setup:**
1. Inbound → Domains → Add domain
2. Add MX records to your DNS
3. Routes: pattern → `https://example.com/rails/action_mailbox/mandrill/inbound_emails`

**Endpoint:** `/rails/action_mailbox/mandrill/inbound_emails`

---

### Relay (Postfix, Exim, Qmail)

For self-hosted MTAs that pipe emails to your app.

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :relay
```

**Credentials:**
```yaml
# credentials.yml.enc
action_mailbox:
  ingress_password: "strong-random-password"
```
Or: `RAILS_INBOUND_EMAIL_PASSWORD` env var.

**Postfix pipe command:**
```bash
bin/rails action_mailbox:ingress:postfix \
  URL=https://example.com/rails/action_mailbox/relay/inbound_emails \
  INGRESS_PASSWORD=your-password
```

**Exim pipe command:**
```bash
bin/rails action_mailbox:ingress:exim \
  URL=https://example.com/rails/action_mailbox/relay/inbound_emails \
  INGRESS_PASSWORD=your-password
```

**Qmail pipe command:**
```bash
bin/rails action_mailbox:ingress:qmail \
  URL=https://example.com/rails/action_mailbox/relay/inbound_emails \
  INGRESS_PASSWORD=your-password
```

**Endpoint:** `/rails/action_mailbox/relay/inbound_emails`  
**Auth:** HTTP Basic (`actionmailbox:PASSWORD`)

**Postfix `/etc/postfix/main.cf` example:**
```
# Forward all mail for inbound domain to the Rails app
virtual_alias_maps = hash:/etc/postfix/virtual
```

```
# /etc/postfix/virtual
@inbound.example.com  rails-app
```

```
# /etc/aliases
rails-app: "|/path/to/app/bin/rails action_mailbox:ingress:postfix URL=https://example.com/rails/action_mailbox/relay/inbound_emails INGRESS_PASSWORD=secret"
```

---

## Advanced Routing Patterns

### Route by Sender (Custom Routing)

Default routing matches recipients. For sender-based or header-based routing, override `ApplicationMailbox.route`:

```ruby
class ApplicationMailbox < ActionMailbox::Base
  # Standard recipient-based routing
  routing(/^support@/i => :support)
  routing(/^billing@/i => :billing)

  # For complex routing, override the routing method:
  def self.route(inbound_email)
    mail = inbound_email.mail

    # Route VIP senders to priority mailbox
    if VipSender.exists?(email: mail.from.first)
      :priority
    else
      super  # Fall back to standard routing
    end
  end
end
```

### Route with Plus Addressing (Reply Tokens)

```ruby
# Matches reply+TOKEN@example.com
routing(/^reply\+(.+)@/i => :replies)

class RepliesMailbox < ApplicationMailbox
  def process
    # Extract the token from the To address
    token = recipient_address.match(/^reply\+(.+)@/i)&.captures&.first
    thread = Thread.find_by!(reply_token: token)
    thread.messages.create!(
      body: mail.decoded,
      author: User.find_by(email_address: mail.from.first)
    )
  end

  private

  def recipient_address
    # Find the matching recipient (could be To, CC, or BCC)
    mail.recipients.find { |addr| addr.match?(/^reply\+/i) }
  end
end
```

### Multiple Domains

```ruby
class ApplicationMailbox < ActionMailbox::Base
  routing(/^support@app\.example\.com$/i   => :support)
  routing(/^support@legacy\.example\.com$/i => :legacy_support)
  routing(/@notifications\.example\.com$/i  => :notifications)
end
```

---

## Working with Email Content

### Multipart Emails (HTML + Text)

Most emails are multipart. Handle both:

```ruby
def process
  # Prefer plain text, fall back to HTML
  body = if mail.multipart?
    mail.text_part&.decoded || strip_html(mail.html_part&.decoded) || ""
  else
    mail.decoded
  end

  create_record(body: body)
end

private

def strip_html(html)
  return nil unless html
  ActionController::Base.helpers.strip_tags(html)
end
```

### Handling Attachments

```ruby
def process
  record = create_main_record

  mail.attachments.each do |attachment|
    # Skip inline images (signatures, logos)
    next if attachment.content_disposition&.start_with?("inline")

    # Skip oversized attachments
    next if attachment.decoded.bytesize > 25.megabytes

    record.files.attach(
      io: StringIO.new(attachment.decoded),
      filename: attachment.filename,
      content_type: attachment.content_type
    )
  end
end
```

### Extracting Inline Images

```ruby
def process
  html_body = mail.html_part&.decoded || ""

  # Replace CID references with Active Storage URLs
  mail.attachments.each do |attachment|
    if attachment.content_id.present?
      cid = attachment.content_id.gsub(/[<>]/, "")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(attachment.decoded),
        filename: attachment.filename,
        content_type: attachment.content_type
      )
      html_body.gsub!("cid:#{cid}", Rails.application.routes.url_helpers.rails_blob_url(blob))
    end
  end
end
```

### Reply Parsing (Stripping Quoted Content)

Emails often include quoted replies. Strip them:

```ruby
# Gemfile
gem "email_reply_trimmer"

# In mailbox
def process
  # Get just the new content, not the quoted reply chain
  fresh_body = EmailReplyTrimmer.trim(mail.decoded)
  create_message(body: fresh_body)
end
```

Or a simple regex approach:

```ruby
def strip_reply(text)
  # Remove content after common reply markers
  text.split(/^[-—]+\s*(?:Original Message|Forwarded message)/i).first ||
  text.split(/^On .+ wrote:$/m).first ||
  text.strip
end
```

### Parsing Structured Data from Email

```ruby
class InvoiceMailbox < ApplicationMailbox
  def process
    # Parse amount from subject: "Invoice #1234 - $500.00"
    if match = mail.subject&.match(/Invoice #(\d+)\s*-\s*\$?([\d,.]+)/)
      invoice_number = match[1]
      amount = match[2].gsub(",", "").to_d
    end

    # Parse data from HTML body
    if mail.html_part
      doc = Nokogiri::HTML(mail.html_part.decoded)
      amount ||= doc.css(".invoice-total").text.gsub(/[^0-9.]/, "").to_d
    end
  end
end
```

---

## Callbacks In Depth

### Available Callbacks

```ruby
class ExampleMailbox < ApplicationMailbox
  before_processing  :method_name   # Runs before process; can halt with bounce_with
  around_processing  :method_name   # Wraps process
  after_processing   :method_name   # Runs after process (only if process succeeds)
end
```

### Conditional Callbacks

```ruby
before_processing :check_rate_limit, if: -> { external_sender? }
before_processing :validate_attachment_size, if: :has_attachments?

private

def external_sender?
  !mail.from.first&.end_with?("@example.com")
end

def has_attachments?
  mail.attachments.any?
end
```

### Using around_processing for Transactions

```ruby
around_processing :wrap_in_transaction

private

def wrap_in_transaction
  ActiveRecord::Base.transaction do
    yield
  end
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.error("Mailbox processing failed: #{e.message}")
  bounce_with ErrorMailer.processing_failed(inbound_email, error: e.message)
  raise ActiveRecord::Rollback
end
```

---

## Testing Patterns

### Basic Mailbox Test

```ruby
require "test_helper"

class SupportMailboxTest < ActionMailbox::TestCase
  setup do
    @user = users(:active_user)
  end

  test "creates ticket from valid email" do
    assert_difference "SupportTicket.count", 1 do
      receive_inbound_email_from_mail(
        to: "support@example.com",
        from: @user.email_address,
        subject: "Help needed",
        body: "I can't log in to my account"
      )
    end

    ticket = SupportTicket.last
    assert_equal "Help needed", ticket.subject
    assert_match "can't log in", ticket.body
    assert_equal @user, ticket.requester
  end

  test "bounces email from unknown sender" do
    inbound = receive_inbound_email_from_mail(
      to: "support@example.com",
      from: "stranger@unknown.com",
      subject: "Hello"
    )

    assert inbound.bounced?
    assert_equal 0, SupportTicket.where(from_email: "stranger@unknown.com").count
  end
end
```

### Testing Routing

```ruby
require "test_helper"

class ApplicationMailboxTest < ActionMailbox::TestCase
  test "routes support@ to SupportMailbox" do
    inbound = create_inbound_email_from_mail(
      to: "support@example.com",
      from: "anyone@test.com"
    )
    assert_equal SupportMailbox, ApplicationMailbox.route(inbound)
  end

  test "routes reply+ addresses to RepliesMailbox" do
    inbound = create_inbound_email_from_mail(
      to: "reply+abc123@example.com",
      from: "user@test.com"
    )
    assert_equal RepliesMailbox, ApplicationMailbox.route(inbound)
  end

  test "does not route unknown addresses" do
    inbound = create_inbound_email_from_mail(
      to: "random@example.com",
      from: "user@test.com"
    )
    # Unmatched emails raise or stay pending depending on config
    assert_raises(ActionMailbox::Router::RoutingError) do
      ApplicationMailbox.route(inbound)
    end
  end
end
```

### Testing with .eml Fixture Files

Save real emails (from mail clients or providers) as `.eml` files:

```ruby
# test/fixtures/files/forwarded_invoice.eml
# (paste raw RFC 822 email content here)

test "processes forwarded invoice email" do
  receive_inbound_email_from_source(
    file_fixture("forwarded_invoice.eml").read
  )

  assert_equal 1, Invoice.count
end
```

**How to get `.eml` files:**
1. Gmail: Open email → Three dots → "Show original" → "Download Original"
2. Apple Mail: Drag email to desktop
3. Thunderbird: File → Save As → File (.eml)
4. Provider webhooks: Log the raw payload

### Testing Attachments

```ruby
test "attaches files from email" do
  # Build an email with attachment
  mail = Mail.new do
    from    "user@example.com"
    to      "support@example.com"
    subject "With attachment"
    body    "See attached"

    add_file filename: "report.pdf", content: "PDF content here"
  end

  receive_inbound_email_from_source(mail.to_s)

  ticket = SupportTicket.last
  assert_equal 1, ticket.files.count
  assert_equal "report.pdf", ticket.files.first.filename.to_s
end
```

### Testing Status Transitions

```ruby
test "marks email as delivered on success" do
  inbound = receive_inbound_email_from_mail(
    to: "support@example.com",
    from: users(:active_user).email_address,
    subject: "Test"
  )

  assert inbound.delivered?
end

test "marks email as failed on exception" do
  # Stub to raise during processing
  SupportMailbox.any_instance.stubs(:process).raises(StandardError, "boom")

  inbound = receive_inbound_email_from_mail(
    to: "support@example.com",
    from: users(:active_user).email_address,
    subject: "Test"
  )

  assert inbound.failed?
end
```

### Including Test Helper in Non-Mailbox Tests

```ruby
class SomeIntegrationTest < ActionDispatch::IntegrationTest
  include ActionMailbox::TestHelper

  test "end-to-end email processing" do
    receive_inbound_email_from_mail(
      to: "support@example.com",
      from: "user@example.com",
      subject: "Integration test"
    )

    # Verify downstream effects
    assert_enqueued_jobs 1, only: NotificationJob
  end
end
```

---

## Error Handling Patterns

### Graceful Failure with Logging

```ruby
class SupportMailbox < ApplicationMailbox
  def process
    user = User.find_by(email_address: mail.from.first)

    if user.nil?
      Rails.logger.warn("[SupportMailbox] Unknown sender: #{mail.from.first}")
      bounce_with SupportMailer.unknown_sender(inbound_email)
      return
    end

    create_ticket(user)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[SupportMailbox] Failed to create ticket: #{e.message}")
    # Let it fail — status becomes 'failed', can retry later
    raise
  end
end
```

### Retry Failed Emails

```ruby
# In a rake task or admin action:
ActionMailbox::InboundEmail.where(status: :failed).find_each do |email|
  email.route  # Re-routes and re-processes
end
```

### Rate Limiting

```ruby
before_processing :check_rate_limit

private

def check_rate_limit
  sender = mail.from.first
  key = "mailbox:rate_limit:#{sender}"
  count = Rails.cache.increment(key, 1, expires_in: 1.hour)

  if count > 50
    Rails.logger.warn("[RateLimit] Sender #{sender} exceeded rate limit")
    bounce_with RateLimitMailer.too_many_emails(inbound_email)
  end
end
```

---

## Incineration Details

### How It Works

1. After processing, `InboundEmail` status becomes `delivered`, `failed`, or `bounced`
2. `ActionMailbox::IncinerationJob` is enqueued to run after `incinerate_after` (default: 30 days)
3. The job destroys the `InboundEmail` record and its Active Storage attachment (raw email blob)

### Configuration

```ruby
# config/environments/production.rb
config.action_mailbox.incinerate_after = 14.days   # Shorter retention
config.action_mailbox.incinerate_after = 90.days   # Longer retention (compliance)
config.action_mailbox.incinerate = false            # Disable incineration entirely
```

### Implications

- **Extract everything in `process`** — after incineration, the raw email is gone
- **Active Storage must be configured** — raw emails are stored as blobs
- **Job queue must support far-future scheduling** — 30-day delayed jobs need a durable backend (Sidekiq, Solid Queue, not in-memory)

---

## Production Checklist

### Before Deploying

- [ ] Action Mailbox and Active Storage migrations ran
- [ ] Ingress configured in `config/environments/production.rb`
- [ ] Credentials set (ingress password or provider API key)
- [ ] Active Job queue adapter configured (not `:async` in production)
- [ ] Active Storage service configured (not `:local` in production unless single-server)
- [ ] DNS records configured for receiving domain (MX records or provider-specific)
- [ ] Provider webhook URL configured and verified
- [ ] SSL/TLS on your endpoint (providers require HTTPS)
- [ ] `bounce_with` mailers created and tested
- [ ] Incineration period reviewed for compliance needs
- [ ] Monitoring/alerting on `failed` status emails

### DNS Setup

For custom inbound email domains:

```
; MX records for inbound.example.com
inbound.example.com.  MX  10  mxa.mailgun.org.
inbound.example.com.  MX  10  mxb.mailgun.org.

; SPF (if also sending from this domain)
inbound.example.com.  TXT  "v=spf1 include:mailgun.org ~all"
```

### Monitoring

```ruby
# Check for stuck/failed emails
ActionMailbox::InboundEmail.where(status: :failed).count
ActionMailbox::InboundEmail.where(status: :pending).where("created_at < ?", 1.hour.ago).count

# In a health check or monitoring job:
class MailboxHealthCheckJob < ApplicationJob
  def perform
    stuck = ActionMailbox::InboundEmail
      .where(status: :pending)
      .where("created_at < ?", 30.minutes.ago)
      .count

    if stuck > 0
      AdminNotifier.mailbox_stuck(count: stuck).deliver_now
    end
  end
end
```

---

## Common Gotchas

### 1. Active Storage Not Set Up

Action Mailbox stores raw emails via Active Storage. If Active Storage isn't configured:
```
ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR: relation "active_storage_blobs" does not exist
```
**Fix:** Run `bin/rails active_storage:install && bin/rails db:migrate`

### 2. Active Job Queue Adapter

Action Mailbox routes emails via Active Job. The default `:async` adapter in development works, but in production use a real backend:
```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue  # or :sidekiq, :good_job, etc.
```

### 3. SendGrid/Postmark Missing Raw MIME

Both require checking a box to include the raw MIME message. Without it, Action Mailbox can't parse the email.

**SendGrid:** Check "Post the raw, full MIME message"  
**Postmark:** Check "Include raw email content in JSON payload"

### 4. Routing Matches CC/BCC Too

```ruby
routing(/^secret@/i => :secret)
```
This matches if `secret@example.com` is in To, CC, or BCC. If you only want To:
```ruby
def self.route(inbound_email)
  if inbound_email.mail.to&.any? { |addr| addr.match?(/^secret@/i) }
    :secret
  else
    super
  end
end
```

### 5. Encoding Issues

Email bodies can have various encodings. Always use `.decoded`:
```ruby
# WRONG — may be base64 or quoted-printable encoded
mail.body.to_s

# RIGHT — properly decoded
mail.decoded
# or
mail.body.decoded
```

### 6. Duplicate Processing

The same email might be delivered multiple times (retries, provider quirks). Guard against it:
```ruby
def process
  # Use message_id for idempotency
  return if SupportTicket.exists?(email_message_id: mail.message_id)

  SupportTicket.create!(
    email_message_id: mail.message_id,
    # ... other fields
  )
end
```

### 7. Forgetting to Handle mail.from as Array

`mail.from` returns an array, not a string:
```ruby
# WRONG
User.find_by(email: mail.from)

# RIGHT
User.find_by(email: mail.from.first)
```

### 8. Testing Without Processing

`create_inbound_email_from_mail` creates but does NOT process. `receive_inbound_email_from_mail` creates AND processes. Use the right one:

```ruby
# For routing tests (don't need processing):
email = create_inbound_email_from_mail(to: "support@example.com", from: "x@y.com")

# For processing tests (need side effects):
email = receive_inbound_email_from_mail(to: "support@example.com", from: "x@y.com")
```

---

## Useful Gems

| Gem | Purpose |
|-----|---------|
| `email_reply_trimmer` | Strip quoted replies from email bodies |
| `griddler` | Alternative to Action Mailbox (provider-specific adapters) |
| `nokogiri` | Parse HTML email bodies |
| `mail` | Already included — the `Mail` gem powers `mail` accessor |

---

## Rails Console Recipes

```ruby
# List all inbound emails
ActionMailbox::InboundEmail.all

# Find by status
ActionMailbox::InboundEmail.where(status: :failed)

# Re-process a failed email
email = ActionMailbox::InboundEmail.find(id)
email.route

# View raw source
puts email.source

# Access parsed mail
email.mail.subject
email.mail.from
email.mail.decoded

# Manually create and process (debugging)
email = ActionMailbox::InboundEmail.create_and_extract_message_id!(
  source: File.read("/path/to/email.eml")
)
email.route
```
