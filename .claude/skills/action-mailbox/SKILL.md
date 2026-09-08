---
name: action-mailbox
description: Expert guidance for receiving and processing inbound emails with Action Mailbox in Rails. Use when setting up inbound email processing, routing emails to mailboxes, configuring ingress providers (Mailgun, SendGrid, Postfix, etc.), handling attachments, bouncing emails, or testing with fixtures. Covers "action mailbox", "inbound email", "receive email", "process email", "email routing", "mailbox", "incoming email", "email processing", "ingress", "InboundEmail".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails action_mailbox:*), Bash(bin/rails generate mailbox *), Bash(bin/rails db:migrate), Bash(bin/rails test:*)
---

# Rails Action Mailbox Expert

Route incoming emails to controller-like mailbox classes for processing in Rails applications.

## Philosophy

**Core Principles:**
1. **Mailboxes are controllers for email** — route by address pattern, process in dedicated classes
2. **Extract data early, incinerate later** — persist domain data from emails immediately; raw emails are temporary
3. **Bounce explicitly** — reject bad emails with informative bounce messages, don't silently swallow them
4. **Test with real email fixtures** — use `.eml` files, not hand-built Mail objects
5. **One mailbox per concern** — keep mailboxes focused; split routing rather than branching in `process`

## When To Use This Skill

- Setting up Action Mailbox in a Rails app
- Configuring an ingress provider (Mailgun, SendGrid, Postmark, Postfix, etc.)
- Writing mailbox classes to process inbound emails
- Routing emails to the correct mailbox
- Handling email attachments via Active Storage
- Bouncing or rejecting invalid emails
- Testing inbound email processing
- Debugging email delivery/processing issues

## Instructions

### Step 1: Install Action Mailbox

```bash
bin/rails action_mailbox:install
bin/rails db:migrate
```

This creates:
- `app/mailboxes/application_mailbox.rb` — the routing hub
- Migration for `action_mailbox_inbound_emails` table
- Active Storage tables (if not already present)

**Verify setup:**
```bash
# Check the migration ran
bin/rails runner "puts ActionMailbox::InboundEmail.table_exists?"

# Check conductor is available (dev only)
# Visit http://localhost:3000/rails/conductor/action_mailbox/inbound_emails
```

### Step 2: Configure Routing

`ApplicationMailbox` is the router. It matches email recipients against patterns and dispatches to mailbox classes.

```ruby
# app/mailboxes/application_mailbox.rb
class ApplicationMailbox < ActionMailbox::Base
  # Route by To/CC/BCC address patterns (regex or string)
  routing(/^support@/i      => :support)
  routing(/^reply\+(.+)@/i  => :replies)
  routing(/@invoices\./i    => :invoices)
  routing(all:              => :catch_all)  # Fallback — use sparingly
end
```

**Routing rules:**
- Patterns match against `to`, `cc`, and `bcc` fields
- First match wins — order matters
- Use `all:` as a catch-all only if every email must be processed
- Unmatched emails stay `pending` and get incinerated

**⚠️ Common mistake:** Forgetting that routing matches ALL recipient fields, not just `to`. An email CC'd to a matching address will also route.

### Step 3: Generate Mailbox Classes

```bash
bin/rails generate mailbox support
```

Creates `app/mailboxes/support_mailbox.rb`:

```ruby
class SupportMailbox < ApplicationMailbox
  def process
    # Your processing logic here
  end
end
```

### Step 4: Implement the Process Method

The `process` method is where you extract data from the email and persist it to your domain models.

```ruby
class SupportMailbox < ApplicationMailbox
  def process
    ticket = SupportTicket.create!(
      subject: mail.subject,
      body: mail.decoded,
      from_email: mail.from.first,
      from_name: mail.from_address&.display_name
    )

    # Handle attachments
    mail.attachments.each do |attachment|
      ticket.files.attach(
        io: StringIO.new(attachment.decoded),
        filename: attachment.filename,
        content_type: attachment.content_type
      )
    end
  end
end
```

**Key accessors on `mail` (a `Mail::Message`):**
- `mail.to` — array of To addresses
- `mail.from` — array of From addresses
- `mail.cc` — array of CC addresses
- `mail.subject` — subject line
- `mail.body.decoded` / `mail.decoded` — decoded body text
- `mail.date` — send date
- `mail.message_id` — unique message ID
- `mail.in_reply_to` — message ID this replies to
- `mail.attachments` — array of attachments
- `mail.multipart?` — whether email has multiple parts
- `mail.text_part` / `mail.html_part` — specific MIME parts

**The `inbound_email` accessor:**
- `inbound_email` — the `ActionMailbox::InboundEmail` Active Record object
- `inbound_email.message_id` — the RFC 2822 Message-ID
- `inbound_email.source` — raw email source (RFC 822)

### Step 5: Use Callbacks for Guards and Side Effects

Action Mailbox provides `before_processing`, `after_processing`, and `around_processing` callbacks.

```ruby
class SupportMailbox < ApplicationMailbox
  before_processing :ensure_known_sender
  before_processing :reject_spam
  after_processing :notify_team

  def process
    create_ticket_from_email
  end

  private

  def ensure_known_sender
    unless User.exists?(email_address: mail.from.first)
      bounce_with SupportMailer.unknown_sender(inbound_email)
    end
  end

  def reject_spam
    if SpamDetector.spam?(mail)
      bounce_with SupportMailer.spam_rejected(inbound_email)
    end
  end

  def notify_team
    SupportNotificationJob.perform_later(@ticket)
  end
end
```

**⚠️ Common mistake:** Not understanding that `bounce_with` halts processing. It sets the status to `bounced`, sends the bounce email, and stops — the `process` method never runs.

### Step 6: Bounce Correctly

`bounce_with` takes an Action Mailer message and:
1. Sends the bounce email
2. Sets `inbound_email.status` to `bounced`
3. Halts further processing

```ruby
# In a before_processing callback:
bounce_with UserMailer.not_authorized(inbound_email)

# The mailer is a normal Action Mailer:
class UserMailer < ApplicationMailer
  def not_authorized(inbound_email)
    @email = inbound_email
    mail(
      to: @email.mail.from.first,
      subject: "Unable to process your email"
    )
  end
end
```

**Rules for bouncing:**
- Always bounce in `before_processing` callbacks, not inside `process`
- Always provide a meaningful bounce email — silent drops confuse senders
- Don't bounce spam — just mark as delivered or let it incenerate silently

### Step 7: Configure Ingress Provider

Set the ingress in `config/environments/production.rb`:

```ruby
config.action_mailbox.ingress = :mailgun  # or :sendgrid, :postmark, :mandrill, :relay
```

**Credentials go in encrypted credentials:**
```bash
bin/rails credentials:edit
```

```yaml
action_mailbox:
  ingress_password: "strong-random-password"     # For relay/postmark/sendgrid
  mailgun_signing_key: "your-mailgun-key"        # For Mailgun
  mandrill_api_key: "your-mandrill-key"          # For Mandrill
```

**Or use environment variables:**
- `RAILS_INBOUND_EMAIL_PASSWORD` — relay ingress password
- `MAILGUN_INGRESS_SIGNING_KEY` — Mailgun signing key
- `MANDRILL_INGRESS_API_KEY` — Mandrill API key

See `reference.md` for provider-specific endpoint URLs and configuration details.

### Step 8: Test Mailboxes

**Use `ActionMailbox::TestCase` and its helpers:**

```ruby
require "test_helper"

class SupportMailboxTest < ActionMailbox::TestCase
  test "creates a support ticket from inbound email" do
    assert_difference "SupportTicket.count", 1 do
      receive_inbound_email_from_mail(
        to: "support@example.com",
        from: "customer@example.com",
        subject: "Help needed",
        body: "I can't log in"
      )
    end

    ticket = SupportTicket.last
    assert_equal "Help needed", ticket.subject
    assert_equal "customer@example.com", ticket.from_email
  end

  test "bounces email from unknown sender" do
    inbound_email = receive_inbound_email_from_mail(
      to: "support@example.com",
      from: "stranger@unknown.com",
      subject: "Hello"
    )

    assert inbound_email.bounced?
  end

  test "routes to support mailbox" do
    assert_equal SupportMailbox, ApplicationMailbox.route(
      receive_inbound_email_from_mail(to: "support@example.com")
    )
  end
end
```

**Testing with `.eml` fixture files:**

```ruby
# Save real emails as test/fixtures/files/welcome_email.eml
test "processes a real email fixture" do
  receive_inbound_email_from_source(
    file_fixture("welcome_email.eml").read
  )
end
```

**⚠️ Common mistake:** Testing with hand-crafted strings instead of realistic email fixtures. Real emails have headers, MIME boundaries, and encoding that simple strings miss. Save actual emails as `.eml` files.

### Step 9: Use the Conductor for Local Testing

In development, visit:
```
http://localhost:3000/rails/conductor/action_mailbox/inbound_emails
```

The conductor lets you:
- Create new inbound emails manually
- View all inbound emails and their status
- Redeliver emails for reprocessing
- Test routing without configuring a real ingress

**Also available via curl:**
```bash
curl -X POST http://localhost:3000/rails/conductor/action_mailbox/inbound_emails \
  -F "inbound_email[raw_email_file]=@path/to/email.eml"
```

### Step 10: Configure Incineration

Processed emails are incinerated (deleted) after 30 days by default.

```ruby
# config/environments/production.rb
config.action_mailbox.incinerate_after = 14.days  # Override default
```

**Important:** Extract all data you need in `process` before relying on the raw email. After incineration, the original email and its Active Storage blob are gone.

**Statuses that trigger incineration:** `delivered`, `failed`, `bounced`

## Quick Reference

### InboundEmail Lifecycle

```
  pending → processing → delivered
                       → failed (exception raised)
                       → bounced (bounce_with called)
```

### Email Address Matching Patterns

```ruby
# Exact local part
routing("support@example.com" => :support)

# Regex on local part
routing(/^reply\+(.+)@/i => :replies)

# Domain matching
routing(/@billing\./i => :billing)

# Catch-all (last resort)
routing(all: => :catch_all)
```

### Mailbox Class Template

```ruby
class ExampleMailbox < ApplicationMailbox
  before_processing :validate_sender

  def process
    # 1. Find or create related records
    user = User.find_by!(email_address: mail.from.first)

    # 2. Extract and persist data
    record = user.messages.create!(
      subject: mail.subject,
      body: mail.decoded,
      received_at: mail.date
    )

    # 3. Handle attachments
    mail.attachments.each do |attachment|
      record.files.attach(
        io: StringIO.new(attachment.decoded),
        filename: attachment.filename,
        content_type: attachment.content_type
      )
    end

    # 4. Trigger side effects
    NotificationJob.perform_later(record)
  end

  private

  def validate_sender
    unless User.exists?(email_address: mail.from.first)
      bounce_with ExampleMailer.unknown_sender(inbound_email)
    end
  end
end
```

### Test Helpers

```ruby
# From ActionMailbox::TestCase / ActionMailbox::TestHelper

# Create and process an inbound email from params
receive_inbound_email_from_mail(to:, from:, subject:, body:, **headers)

# Create and process from raw RFC 822 source
receive_inbound_email_from_source(source)

# Create without processing (for routing tests)
create_inbound_email_from_mail(to:, from:, subject:, body:)
create_inbound_email_from_source(source)

# Status checks on returned InboundEmail
inbound_email.delivered?
inbound_email.bounced?
inbound_email.failed?
inbound_email.pending?
inbound_email.processing?
```

## Anti-Patterns to Avoid

1. **Giant process methods** — Extract to service objects; mailbox should orchestrate, not implement
2. **No bounce handling** — Always validate sender/content before processing
3. **Ignoring multipart emails** — Use `mail.text_part` or `mail.html_part`, not just `mail.body`
4. **Relying on raw email after incineration** — Extract data into domain models immediately
5. **Catch-all without filtering** — `routing(all:)` catches spam too; filter aggressively
6. **Testing only happy path** — Test bounces, unknown senders, missing fields, spam
7. **Hardcoding ingress passwords** — Use credentials or environment variables
8. **Processing in callbacks** — Use callbacks for guards only; business logic goes in `process`
9. **Not setting up Active Job** — Action Mailbox routes asynchronously via Active Job; ensure your queue adapter works
10. **Forgetting Active Storage** — Action Mailbox stores raw emails via Active Storage; both must be migrated
