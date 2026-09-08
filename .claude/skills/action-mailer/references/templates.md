# Template Patterns

HTML and text email templates, partials, conditional content, and rendering options.

---

## Mailer Class Patterns

### Basic Mailer

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome!")
  end
end
```

### Mailer with Multiple Actions

```ruby
class UserMailer < ApplicationMailer
  default from: "noreply@example.com"

  def welcome_email
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome to Our App")
  end

  def password_reset
    @user = params[:user]
    @token = params[:token]
    mail(to: @user.email, subject: "Reset Your Password")
  end

  def account_confirmation
    @user = params[:user]
    @confirmation_url = confirm_account_url(token: params[:token])
    mail(to: @user.email, subject: "Confirm Your Account")
  end
end
```

### Parameterized Mailer with before_action

This is the preferred pattern for mailers with shared context across actions:

```ruby
class OrderMailer < ApplicationMailer
  before_action :set_order_and_customer

  default to: -> { @customer.email }

  def confirmation
    mail(subject: "Order ##{@order.number} confirmed")
  end

  def shipped
    @tracking_url = params[:tracking_url]
    mail(subject: "Order ##{@order.number} has shipped!")
  end

  def delivered
    mail(subject: "Order ##{@order.number} delivered")
  end

  def refunded
    @refund_amount = params[:refund_amount]
    mail(subject: "Refund for Order ##{@order.number}")
  end

  private

  def set_order_and_customer
    @order = params[:order]
    @customer = @order.customer
  end
end

# Calling:
OrderMailer.with(order: @order).confirmation.deliver_later
OrderMailer.with(order: @order, tracking_url: url).shipped.deliver_later
```

### Dynamic Default Recipients

```ruby
class AdminMailer < ApplicationMailer
  default to: -> { Admin.pluck(:email) },
          from: "system@example.com"

  def new_registration(user)
    @user = user
    mail(subject: "New User Signup: #{@user.email}")
  end
end
```

### Display Names in From/To

```ruby
class NotificationMailer < ApplicationMailer
  def notify
    @user = params[:user]
    mail(
      to: email_address_with_name(@user.email, @user.full_name),
      from: email_address_with_name("support@example.com", "MyApp Support"),
      reply_to: email_address_with_name("help@example.com", "MyApp Help Desk"),
      subject: "You have a new notification"
    )
  end
end
```

### Multiple Recipients, CC, BCC

```ruby
def team_update
  @team = params[:team]
  mail(
    to: @team.members.pluck(:email),
    cc: @team.managers.pluck(:email),
    bcc: ["analytics@example.com"],
    subject: "Team Update: #{@team.name}"
  )
end
```

---

## Standard HTML Template

```html+erb
<%# app/views/user_mailer/welcome_email.html.erb %>
<h1>Welcome, <%= @user.name %>!</h1>

<p>Thanks for joining. Here's what you can do next:</p>

<ul>
  <li><%= link_to "Complete your profile", edit_profile_url %></li>
  <li><%= link_to "Explore the dashboard", dashboard_url %></li>
  <li><%= link_to "Read the getting started guide", guide_url %></li>
</ul>

<p>
  If you have any questions, just reply to this email.
</p>

<p>
  — The <%= @company_name %> Team
</p>
```

## Standard Text Template

```erb
<%# app/views/user_mailer/welcome_email.text.erb %>
Welcome, <%= @user.name %>!

Thanks for joining. Here's what you can do next:

* Complete your profile: <%= edit_profile_url %>
* Explore the dashboard: <%= dashboard_url %>
* Read the getting started guide: <%= guide_url %>

If you have any questions, just reply to this email.

— The <%= @company_name %> Team
```

## Template with Conditional Content

```html+erb
<h1>Order #<%= @order.number %> Update</h1>

<% if @order.shipped? %>
  <p>Your order has shipped!</p>
  <p>Tracking number: <strong><%= @order.tracking_number %></strong></p>
  <p><%= link_to "Track your package", @tracking_url %></p>
<% elsif @order.confirmed? %>
  <p>Your order has been confirmed and is being prepared.</p>
<% end %>

<h2>Order Summary</h2>
<table>
  <% @order.line_items.each do |item| %>
    <tr>
      <td><%= item.name %></td>
      <td><%= number_to_currency(item.price) %></td>
    </tr>
  <% end %>
  <tr>
    <td><strong>Total</strong></td>
    <td><strong><%= number_to_currency(@order.total) %></strong></td>
  </tr>
</table>
```

## Using Partials in Mailer Views

```html+erb
<%# app/views/user_mailer/welcome_email.html.erb %>
<h1>Welcome!</h1>
<%= render "shared/mailer_header" %>
<p>Content here...</p>
<%= render partial: "order_summary", locals: { order: @order } %>
<%= render "shared/mailer_footer" %>
```

## Rendering Without Templates

```ruby
def simple_notification
  mail(
    to: params[:user].email,
    subject: "Quick Update",
    body: "Your request has been processed.",
    content_type: "text/plain"
  )
end
```

## Explicit Format Block

```ruby
def welcome_email
  @user = params[:user]
  mail(to: @user.email, subject: "Welcome") do |format|
    format.html { render "custom_welcome_template" }
    format.text { render plain: "Welcome, #{@user.name}!" }
  end
end
```

## Attachments Deep Dive

### Simple File Attachment

```ruby
def invoice_email
  @invoice = params[:invoice]
  attachments["invoice-#{@invoice.number}.pdf"] = @invoice.generate_pdf
  mail(to: @invoice.customer_email, subject: "Invoice ##{@invoice.number}")
end
```

### Attachment with Explicit MIME Type

```ruby
def report_email
  attachments["report.csv"] = {
    mime_type: "text/csv",
    content: generate_csv(@report_data)
  }
  mail(to: params[:user].email, subject: "Your Report")
end
```

### Multiple Attachments

```ruby
def document_bundle
  @documents = params[:documents]
  @documents.each do |doc|
    attachments[doc.filename] = doc.download
  end
  mail(to: params[:user].email, subject: "Your Documents")
end
```

### Inline Attachment (Image in Email Body)

```ruby
# In mailer
def branded_email
  attachments.inline["logo.png"] = File.read(
    Rails.root.join("app/assets/images/logo.png")
  )
  attachments.inline["banner.jpg"] = File.read(
    Rails.root.join("app/assets/images/email-banner.jpg")
  )
  mail(to: params[:user].email, subject: "Newsletter")
end
```

```html+erb
<%# In template %>
<div style="text-align: center;">
  <%= image_tag attachments["logo.png"].url, alt: "Company Logo", width: "150" %>
</div>

<%= image_tag attachments["banner.jpg"].url, alt: "Banner", style: "width: 100%;" %>

<p>Hello <%= @user.name %>,</p>
<p>Here's your weekly newsletter...</p>
```

### Active Storage Attachment

```ruby
def receipt_email
  @receipt = params[:receipt]
  if @receipt.pdf_file.attached?
    attachments["receipt.pdf"] = {
      mime_type: @receipt.pdf_file.content_type,
      content: @receipt.pdf_file.download
    }
  end
  mail(to: @receipt.user.email, subject: "Your Receipt")
end
```

## I18n for Emails

### Subject Translation (Automatic)

```ruby
def welcome_email
  @user = params[:user]
  mail(to: @user.email) # Subject auto-looked up from I18n
end
```

```yaml
# config/locales/en.yml
en:
  user_mailer:
    welcome_email:
      subject: "Welcome to Our App!"
```

### Subject with Interpolation

```yaml
en:
  user_mailer:
    welcome_email:
      subject: "Welcome to %{app_name}, %{user_name}!"
```

```ruby
def welcome_email
  @user = params[:user]
  mail(
    to: @user.email,
    subject: default_i18n_subject(app_name: "MyApp", user_name: @user.name)
  )
end
```

### Full I18n Templates

```yaml
# config/locales/en.yml
en:
  user_mailer:
    welcome_email:
      subject: "Welcome!"
      greeting: "Hello %{name},"
      body: "Thanks for joining our platform."
      cta: "Get Started"

# config/locales/es.yml
es:
  user_mailer:
    welcome_email:
      subject: "¡Bienvenido!"
      greeting: "Hola %{name},"
      body: "Gracias por unirte a nuestra plataforma."
      cta: "Comenzar"
```

```html+erb
<h1><%= t(".greeting", name: @user.name) %></h1>
<p><%= t(".body") %></p>
<p><%= link_to t(".cta"), @login_url %></p>
```

### Setting Locale per Email

```ruby
def welcome_email
  @user = params[:user]
  I18n.with_locale(@user.locale || :en) do
    mail(to: @user.email)
  end
end
```

## Layouts and Shared Partials

### Default Mailer Layout

```html+erb
<%# app/views/layouts/mailer.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
      a { color: #0066cc; }
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

```erb
<%# app/views/layouts/mailer.text.erb %>
<%= yield %>

--
Sent by MyApp | https://www.example.com
```

### Custom Layout per Mailer

```ruby
class MarketingMailer < ApplicationMailer
  layout "marketing_email"
end
```

### Custom Layout per Action

```ruby
def welcome_email
  mail(to: @user.email, subject: "Welcome") do |format|
    format.html { render layout: "branded_email" }
    format.text
  end
end
```

## URLs and Assets in Emails

### URL Configuration

```ruby
# config/environments/production.rb
config.action_mailer.default_url_options = { host: "www.example.com", protocol: "https" }
config.action_mailer.asset_host = "https://cdn.example.com"
```

### Always Use _url, Never _path

```erb
<%# CORRECT — absolute URL %>
<%= link_to "View", order_url(@order) %>
<%= edit_profile_url %>

<%# WRONG — relative path, will break %>
<%= link_to "View", order_path(@order) %>
```
