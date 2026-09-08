# Preview Patterns

Mailer previews for iterating on email design without sending real emails.

---

## Basic Preview

```ruby
# test/mailers/previews/user_mailer_preview.rb
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    UserMailer.with(user: User.first).welcome_email
  end
end
```

## Preview with Fallback Data

```ruby
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.first || User.new(
      name: "Jane Doe",
      email: "jane@example.com",
      login: "janedoe"
    )
    UserMailer.with(user: user).welcome_email
  end
end
```

## Preview All Actions

```ruby
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    OrderMailer.with(order: sample_order).confirmation
  end

  def shipped
    OrderMailer.with(
      order: sample_order,
      tracking_url: "https://track.example.com/ABC123"
    ).shipped
  end

  def delivered
    OrderMailer.with(order: sample_order).delivered
  end

  private

  def sample_order
    Order.includes(:line_items, :customer).first || build_sample_order
  end

  def build_sample_order
    Order.new(
      number: "ORD-PREVIEW-001",
      customer: Customer.new(name: "Preview Customer", email: "preview@example.com")
    )
  end
end
```

## Custom Preview Path

```ruby
# config/application.rb
config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
```

## Viewing Previews

- **All previews:** `http://localhost:3000/rails/mailers`
- **Specific mailer:** `http://localhost:3000/rails/mailers/user_mailer`
- **Specific action:** `http://localhost:3000/rails/mailers/user_mailer/welcome_email`

Previews auto-reload when templates change. No server restart needed.
