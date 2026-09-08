# Testing Patterns

Mailer tests, delivery assertions, attachment testing, and integration test patterns.

---

## Basic Mailer Test

```ruby
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome_email sends to user" do
    user = users(:active_user)
    email = UserMailer.with(user: user).welcome_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [user.email], email.to
    assert_equal ["notifications@example.com"], email.from
    assert_equal "Welcome to MyApp", email.subject
  end

  test "welcome_email includes user name in body" do
    user = users(:active_user)
    email = UserMailer.with(user: user).welcome_email

    assert_match user.name, email.html_part.body.to_s
    assert_match user.name, email.text_part.body.to_s
  end

  test "welcome_email has both HTML and text parts" do
    user = users(:active_user)
    email = UserMailer.with(user: user).welcome_email

    assert_not_nil email.html_part
    assert_not_nil email.text_part
  end
end
```

## Testing deliver_later (Enqueued Jobs)

```ruby
test "welcome_email is enqueued for later delivery" do
  user = users(:active_user)

  assert_enqueued_emails 1 do
    UserMailer.with(user: user).welcome_email.deliver_later
  end
end

test "no email enqueued for invalid user" do
  assert_no_enqueued_emails do
    # action that shouldn't enqueue
  end
end
```

## Testing Attachments

```ruby
test "invoice_email includes PDF attachment" do
  invoice = invoices(:paid_invoice)
  email = InvoiceMailer.with(invoice: invoice).invoice_email

  assert_equal 1, email.attachments.size
  attachment = email.attachments.first
  assert_equal "invoice-#{invoice.number}.pdf", attachment.filename
  assert_equal "application/pdf", attachment.content_type.split(";").first
end
```

## Testing with assert_emails

```ruby
# Exactly N emails sent
assert_emails 2 do
  UserMailer.with(user: user1).welcome_email.deliver_now
  UserMailer.with(user: user2).welcome_email.deliver_now
end

# No emails sent
assert_no_emails do
  # nothing happens
end

# Check deliveries array
UserMailer.with(user: user).welcome_email.deliver_now
email = ActionMailer::Base.deliveries.last
assert_equal "Welcome", email.subject
```

## Integration Test — Email from Controller Action

```ruby
require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "creating user sends welcome email" do
    assert_emails 1 do
      post users_path, params: {
        user: { name: "New User", email: "new@example.com", login: "newuser" }
      }
    end
  end

  test "creating user enqueues welcome email" do
    assert_enqueued_emails 1 do
      post users_path, params: {
        user: { name: "New User", email: "new@example.com", login: "newuser" }
      }
    end
  end
end
```
