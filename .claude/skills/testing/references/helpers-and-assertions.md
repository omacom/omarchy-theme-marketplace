# Helpers and Assertions Reference

Test helpers, assertions, and patterns for mailers, jobs, Action Cable, view helpers, and view tests.

---

## Mailer Tests In Depth

### Testing Multipart Emails (HTML + Text)

```ruby
test "sends multipart welcome email" do
  email = UserMailer.welcome(users(:new_user))

  # Test HTML part
  assert_match "<h1>Welcome</h1>", email.html_part.body.to_s
  assert_match "click here", email.html_part.body.to_s

  # Test text part
  assert_match "Welcome", email.text_part.body.to_s
  refute_match "<h1>", email.text_part.body.to_s  # No HTML in text part
end
```

### Testing Attachments

```ruby
test "sends invoice with PDF attachment" do
  email = InvoiceMailer.send_invoice(invoices(:pending))

  assert_equal 1, email.attachments.size
  attachment = email.attachments.first
  assert_equal "invoice-001.pdf", attachment.filename
  assert_equal "application/pdf", attachment.content_type
end
```

### Testing Parameterized Mailers

```ruby
test "parameterized mailer uses correct tenant" do
  email = TenantMailer.with(tenant: tenants(:acme)).welcome(users(:admin))

  assert_match "Acme Corp", email.subject
  assert_equal ["noreply@acme.example.com"], email.from
end

test "enqueues parameterized mailer" do
  assert_enqueued_email_with TenantMailer.with(tenant: tenants(:acme)),
    :welcome, args: [users(:admin)] do
    TenantMailer.with(tenant: tenants(:acme)).welcome(users(:admin)).deliver_later
  end
end
```

### Mailer Previews (Not Tests, But Useful)

```ruby
# test/mailers/previews/user_mailer_preview.rb
class UserMailerPreview < ActionMailer::Preview
  def welcome
    UserMailer.welcome(User.first)
  end

  def password_reset
    UserMailer.password_reset(User.first)
  end
end

# View at: http://localhost:3000/rails/mailers/user_mailer/welcome
```

### Functional Email Testing (From Request Tests)

```ruby
test "password reset sends email" do
  user = users(:admin)

  assert_emails 1 do
    post password_resets_url, params: { email: user.email }
  end

  email = ActionMailer::Base.deliveries.last
  assert_equal [user.email], email.to
  assert_match "reset", email.subject.downcase
end
```

---

## Job Tests In Depth

### Testing Job Enqueuing Details

```ruby
class NotificationJobTest < ActiveJob::TestCase
  test "enqueues with correct queue" do
    assert_enqueued_with(job: NotificationJob, queue: "notifications") do
      NotificationJob.perform_later(users(:admin), "Hello")
    end
  end

  test "enqueues with scheduled time" do
    assert_enqueued_with(job: ReminderJob, at: 1.hour.from_now.to_f) do
      ReminderJob.set(wait: 1.hour).perform_later(users(:admin))
    end
  end

  test "enqueues multiple jobs" do
    assert_enqueued_jobs 3 do
      3.times { NotificationJob.perform_later(users(:admin), "Hello") }
    end
  end
end
```

### Testing Job Side Effects

```ruby
test "import job processes CSV and creates records" do
  csv_path = file_fixture("products.csv")

  assert_difference "Product.count", 5 do
    perform_enqueued_jobs do
      ImportJob.perform_later(csv_path.to_s)
    end
  end
end

test "cleanup job removes old records" do
  assert_difference "Session.count", -3 do
    perform_enqueued_jobs do
      CleanupJob.perform_later
    end
  end
end
```

### Testing Jobs That Send Emails

```ruby
test "welcome job sends email" do
  user = users(:new_user)

  assert_emails 1 do
    perform_enqueued_jobs do
      WelcomeJob.perform_later(user)
    end
  end
end
```

### Testing Jobs That Enqueue Other Jobs

```ruby
test "batch job enqueues individual jobs" do
  users = [users(:admin), users(:regular)]

  assert_enqueued_jobs 2, only: NotificationJob do
    BatchNotifyJob.perform_now(users)
  end
end
```

### Filtering Performed Jobs

```ruby
test "only performs specific job types" do
  perform_enqueued_jobs(only: ProcessOrderJob) do
    ProcessOrderJob.perform_later(orders(:new))
    NotificationJob.perform_later(users(:admin), "Processed")
  end

  # ProcessOrderJob ran, NotificationJob is still queued
  assert_enqueued_jobs 1, only: NotificationJob
end
```

---

## Action Cable Tests In Depth

### Channel with Custom Methods

```ruby
class ChatChannelTest < ActionCable::Channel::TestCase
  test "receives broadcasted messages" do
    subscribe room: "general"

    perform :speak, message: "Hello!"

    # Assert the broadcast happened
    assert_broadcast_on("chat_general", message: "Hello!", user: "anonymous")
  end
end
```

### Testing Streams

```ruby
class NotificationsChannelTest < ActionCable::Channel::TestCase
  test "streams for current user" do
    stub_connection current_user: users(:admin)
    subscribe

    assert_has_stream_for users(:admin)
  end

  test "streams for specific model" do
    stub_connection current_user: users(:admin)
    project = projects(:active)
    subscribe project_id: project.id

    assert_has_stream_for project
  end
end
```

### Broadcast Assertions from Models/Controllers

```ruby
class MessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "broadcasts new message" do
    room = rooms(:general)

    assert_broadcasts("chat_#{room.id}", 1) do
      Message.create!(room: room, body: "Hello!", user: users(:admin))
    end
  end

  test "broadcasts with specific payload" do
    room = rooms(:general)

    assert_broadcast_on("chat_#{room.id}", {
      body: "Hello!",
      user: "Admin"
    }) do
      Message.create!(room: room, body: "Hello!", user: users(:admin))
    end
  end
end
```

---

## Helper Tests In Depth

```ruby
class ApplicationHelperTest < ActionView::TestCase
  test "page_title with custom title" do
    assert_equal "My App | Dashboard", page_title("Dashboard")
  end

  test "page_title with default" do
    assert_equal "My App", page_title
  end

  test "renders markdown to HTML" do
    result = render_markdown("**bold** and *italic*")
    assert_dom_equal "<p><strong>bold</strong> and <em>italic</em></p>", result
  end

  test "time_ago_in_words helper" do
    # ActionView helpers are available
    assert_match /ago/, time_ago_in_words(3.hours.ago)
  end
end
```

### Testing Helpers That Use Request Context

```ruby
class NavigationHelperTest < ActionView::TestCase
  test "active_link_class returns active for current path" do
    # Stub the request
    controller.request = ActionDispatch::TestRequest.create
    controller.request.path = "/articles"

    assert_equal "active", active_link_class("/articles")
    assert_nil active_link_class("/users")
  end
end
```

---

## View Tests In Depth

### Testing Partials

```ruby
class ArticlePartialTest < ActionView::TestCase
  test "renders article title" do
    article = articles(:published)
    render partial: "articles/article", locals: { article: article }

    assert_includes rendered, article.title
    assert_dom "a[href=?]", article_path(article)
  end
end
```

### Parsed Content Testing (Rails 7.1+)

```ruby
class ApiArticleViewTest < ActionView::TestCase
  test "renders JSON correctly" do
    article = articles(:published)
    render formats: :json, partial: "articles/article", locals: { article: article }

    json = rendered.json
    assert_equal article.title, json[:title]
    assert_equal article.id, json[:id]
  end
end
```

---

## Rails-Specific Assertions Reference

### Record Change Assertions

```ruby
# Count changes
assert_difference "Article.count", 1 do
  Article.create!(title: "New")
end

assert_difference "Article.count", -1 do
  @article.destroy
end

assert_no_difference "Article.count" do
  Article.new.save  # fails validation
end

# Multiple counts at once
assert_difference ["Article.count", "Comment.count"], 1 do
  Article.create_with_comment!(...)
end

# Value changes
assert_changes -> { @user.reload.name }, from: "Old", to: "New" do
  @user.update!(name: "New")
end

assert_no_changes -> { @user.reload.email } do
  @user.update!(name: "New Name")
end
```

### Response Assertions

```ruby
assert_response :success        # 200-299
assert_response :redirect       # 300-399
assert_response :missing        # 404
assert_response :error          # 500-599
assert_response 201             # specific status
assert_response :created        # symbolic status

assert_redirected_to article_path(@article)
assert_redirected_to root_url
assert_redirected_to %r{/articles/\d+}  # regex match
```

### Query Assertions (Rails 7.1+)

```ruby
# Assert exact query count
assert_queries_count(2) do
  User.find(1)
  User.find(2)
end

# Assert no queries (e.g., testing caching)
assert_no_queries do
  Rails.cache.read("key")
end

# Assert query pattern
assert_queries_match(/SELECT.*FROM.*users/) do
  User.all.to_a
end

# Assert no queries matching pattern
assert_no_queries_match(/INSERT/) do
  User.all.to_a
end
```

### Email Assertions

```ruby
# Count emails sent
assert_emails 1 do
  UserMailer.welcome(@user).deliver_now
end

assert_no_emails do
  # action that shouldn't send email
end

# Count enqueued emails
assert_enqueued_emails 1 do
  UserMailer.welcome(@user).deliver_later
end

# Assert specific email enqueued
assert_enqueued_email_with UserMailer, :welcome, args: [@user] do
  UserMailer.welcome(@user).deliver_later
end
```

### Error Reporting Assertions (Rails 7.1+)

```ruby
assert_error_reported(IOError) do
  Rails.error.report(IOError.new("disk full"))
end

assert_no_error_reported do
  perform_safe_operation
end
```

### Routing Assertions

```ruby
# Path generates correct route
assert_generates "/articles/1", controller: "articles", action: "show", id: "1"

# Route recognizes path
assert_recognizes({ controller: "articles", action: "show", id: "1" }, "/articles/1")

# Both directions at once
assert_routing "/articles/1", controller: "articles", action: "show", id: "1"
```

### DOM Assertions

```ruby
# Element exists
assert_select "h1", "Welcome"
assert_select "h1", /welcome/i
assert_select ".article", count: 3
assert_select ".article", minimum: 1
assert_select ".article", maximum: 10
assert_select ".error", false  # must not exist
assert_select ".error", count: 0  # same as above

# Nested assertions
assert_select "table tr" do
  assert_select "td", minimum: 3
end

# In email body
assert_dom_email do
  assert_select "a[href=?]", confirmation_url
end
```
