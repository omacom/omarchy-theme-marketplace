# Rails Minitest Reference

Detailed patterns and advanced usage for Rails Minitest testing.

## Table of Contents
- [Fixture Patterns](#fixture-patterns)
- [Test Helper Patterns](#test-helper-patterns)
- [Advanced Test Patterns](#advanced-test-patterns)
- [Request Test Patterns](#request-test-patterns)
- [System Test Patterns](#system-test-patterns)
- [Performance Testing](#performance-testing)
- [Parallel Testing](#parallel-testing)
- [Debugging Slow Tests](#debugging-slow-tests)

## Fixture Patterns

### Basic Fixture Structure

```yaml
# test/fixtures/users.yml

# Include schema comment for reference
# == Schema Information
#
# Table name: users
#
#  id         :uuid             not null, primary key
#  email      :string           not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null

# Use descriptive names indicating test purpose
active_admin:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "active_admin") %>
  email: "admin@example.com"
  name: "Admin User"
  created_at: <%= 1.week.ago %>
  updated_at: <%= 1.week.ago %>

inactive_member:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "inactive_member") %>
  email: "inactive@example.com"
  name: "Inactive Member"
  active: false
  created_at: <%= 1.month.ago %>
  updated_at: <%= 1.month.ago %>
```

### Association Patterns

```yaml
# test/fixtures/posts.yml
admin_post:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "admin_post") %>
  title: "Admin's Post"
  author: active_admin  # Reference by fixture name
  workspace: main_workspace
  published: true

# test/fixtures/comments.yml
first_comment:
  post: admin_post  # Reference by fixture name
  author: inactive_member
  body: "Great post!"
```

### Dynamic Fixture Generation

```yaml
# Generate multiple similar fixtures
<% 5.times do |n| %>
test_post_<%= n %>:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "test_post_#{n}") %>
  title: <%= "Test Post #{n}" %>
  author: active_admin
  workspace: main_workspace
  published: <%= n.even? %>
<% end %>
```

### Polymorphic Associations

```yaml
# test/fixtures/comments.yml
post_comment:
  commentable: admin_post (Post)  # Specify type in parentheses
  author: active_admin
  body: "Comment on post"

article_comment:
  commentable: featured_article (Article)
  author: active_admin
  body: "Comment on article"
```

## Test Helper Patterns

### Custom Assertions

```ruby
# test/support/custom_assertions.rb
module CustomAssertions
  def assert_valid(record, msg = nil)
    assert record.valid?, msg || "Expected #{record.class} to be valid: #{record.errors.full_messages.join(', ')}"
  end

  def assert_invalid(record, attribute, msg = nil)
    refute record.valid?, msg || "Expected #{record.class} to be invalid"
    assert record.errors[attribute].any?, msg || "Expected errors on #{attribute}"
  end

  def assert_authorized(policy, action)
    assert policy.public_send(action), "Expected #{policy.class}##{action} to be authorized"
  end

  def assert_unauthorized(policy, action)
    refute policy.public_send(action), "Expected #{policy.class}##{action} to be unauthorized"
  end
end

# Include in test_helper.rb
class ActiveSupport::TestCase
  include CustomAssertions
end
```

### Shared Test Modules

```ruby
# test/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password" }
  end

  def sign_out
    delete session_path
  end

  def authenticated_get(path, user:, **options)
    sign_in_as(user)
    get path, **options
  end
end

# test/support/tenant_helpers.rb
module TenantHelpers
  def with_tenant(workspace)
    ActsAsTenant.with_tenant(workspace) do
      Current.workspace = workspace
      yield
    ensure
      Current.workspace = nil
    end
  end
end
```

### Permission Helpers

```ruby
# test/support/permission_helpers.rb
module PermissionHelpers
  def grant_permission(user, workspace, *permissions)
    membership = user.workspace_memberships.find_by(workspace: workspace)
    permissions.each do |permission|
      membership.update!(permission => true)
    end
  end

  def deny_all_permissions(user, workspace)
    membership = user.workspace_memberships.find_by(workspace: workspace)
    permission_columns = membership.class.column_names.select { |c| c.start_with?("allowed_to_") }
    membership.update!(permission_columns.index_with { false })
  end

  def with_permission(user, workspace, permission)
    grant_permission(user, workspace, permission)
    yield
  ensure
    deny_all_permissions(user, workspace)
  end
end
```

## Advanced Test Patterns

### Testing Time-Dependent Code

```ruby
test "subscription expires after one year" do
  user = users(:subscriber)
  user.update!(subscribed_at: Time.current)

  travel_to 1.year.from_now do
    assert user.subscription_expired?
  end
end

test "discount valid during sale period" do
  freeze_time do
    travel_to Date.new(2025, 12, 25) do
      assert Product.christmas_sale_active?
    end
  end
end

test "job scheduled for tomorrow" do
  travel_to Time.zone.parse("2025-01-15 10:00") do
    assert_enqueued_with(at: Time.zone.parse("2025-01-16 10:00")) do
      ReminderJob.perform_later(users(:active_admin))
    end
  end
end
```

### Testing Background Jobs

```ruby
# Test job is enqueued
test "creates notification job on save" do
  assert_enqueued_with(job: NotificationJob) do
    Post.create!(title: "Test", author: users(:active_admin))
  end
end

# Test job behavior directly
test "notification job sends email" do
  post = posts(:admin_post)
  
  assert_emails 1 do
    perform_enqueued_jobs do
      NotificationJob.perform_later(post)
    end
  end
end

# Test all jobs processed
test "complete workflow processes all jobs" do
  perform_enqueued_jobs do
    PostPublisher.new(posts(:draft_post)).publish!
  end
  
  assert posts(:draft_post).reload.published?
  assert_emails 1
end
```

### Testing Mailers

```ruby
test "welcome email has correct content" do
  user = users(:new_user)
  email = UserMailer.welcome(user)

  assert_emails 1 do
    email.deliver_now
  end

  assert_equal ["welcome@example.com"], email.from
  assert_equal [user.email], email.to
  assert_equal "Welcome to Our App!", email.subject
  assert_match user.name, email.body.encoded
end

test "email is enqueued on user creation" do
  assert_enqueued_emails 1 do
    User.create!(email: "new@example.com", name: "New User")
  end
end
```

### Testing File Uploads

```ruby
test "accepts valid image upload" do
  post = posts(:admin_post)
  image = fixture_file_upload("test/fixtures/files/sample.png", "image/png")

  post.image.attach(image)

  assert post.image.attached?
  assert_equal "sample.png", post.image.filename.to_s
end

test "rejects invalid file type" do
  post = posts(:admin_post)
  file = fixture_file_upload("test/fixtures/files/document.pdf", "application/pdf")

  post.image.attach(file)

  refute post.valid?
  assert_includes post.errors[:image], "must be an image"
end
```

### Testing API Responses

```ruby
test "API returns paginated results" do
  get api_v1_posts_path, headers: { "Authorization" => "Bearer #{@token}" }

  assert_response :success
  json = JSON.parse(response.body)

  assert json.key?("posts")
  assert json.key?("meta")
  assert_equal 1, json["meta"]["current_page"]
  assert json["meta"]["total_pages"].positive?
end

test "API validates request format" do
  post api_v1_posts_path,
       params: { post: { title: "" } }.to_json,
       headers: {
         "Authorization" => "Bearer #{@token}",
         "Content-Type" => "application/json"
       }

  assert_response :unprocessable_entity
  json = JSON.parse(response.body)
  assert json["errors"]["title"].include?("can't be blank")
end
```

### Testing Callbacks

```ruby
test "normalizes email before save" do
  user = User.new(email: "  TEST@EXAMPLE.COM  ", name: "Test")
  user.save!

  assert_equal "test@example.com", user.email
end

test "generates slug from title on create" do
  post = Post.create!(title: "My Great Post", author: users(:active_admin))

  assert_equal "my-great-post", post.slug
end

test "after_commit triggers notification" do
  assert_enqueued_with(job: NotificationJob) do
    Post.create!(title: "Test", author: users(:active_admin))
  end
end
```

### Testing Scopes

```ruby
test ".published returns only published posts" do
  published = posts(:published_post)
  draft = posts(:draft_post)

  results = Post.published

  assert_includes results, published
  refute_includes results, draft
end

test ".recent orders by created_at descending" do
  old_post = posts(:old_post)
  new_post = posts(:new_post)

  results = Post.recent

  assert_equal new_post, results.first
  assert results.index(new_post) < results.index(old_post)
end

test ".search finds matching records" do
  matching = posts(:admin_post)
  matching.update!(title: "Ruby on Rails Guide")

  results = Post.search("rails")

  assert_includes results, matching
end
```

## Request Test Patterns

### Testing Turbo Streams

```ruby
test "creates post and returns turbo stream" do
  sign_in users(:active_admin)

  post posts_path,
       params: { post: { title: "New Post" } },
       as: :turbo_stream

  assert_response :success
  assert_match "turbo-stream", response.media_type
  assert_match "append", response.body
end

test "validation error returns turbo stream with form" do
  sign_in users(:active_admin)

  post posts_path,
       params: { post: { title: "" } },
       as: :turbo_stream

  assert_response :unprocessable_entity
  assert_match "replace", response.body
  assert_match "error", response.body
end
```

### Testing Authentication

```ruby
test "redirects unauthenticated user to login" do
  get posts_path

  assert_redirected_to new_session_path
end

test "allows authenticated user" do
  sign_in users(:active_admin)

  get posts_path

  assert_response :success
end

test "redirects unauthorized user" do
  sign_in users(:member_without_access)

  get admin_posts_path

  assert_response :forbidden
  # OR assert_redirected_to root_path
end
```

### Testing Subdomain Routing

```ruby
setup do
  @workspace = workspaces(:main_workspace)
  host! "#{@workspace.subdomain}.example.com"
end

test "routes to correct workspace" do
  sign_in users(:active_admin)

  get posts_path

  assert_response :success
  assert_equal @workspace, controller.current_workspace
end

test "rejects invalid subdomain" do
  host! "invalid.example.com"

  get posts_path

  assert_response :not_found
end
```

## System Test Patterns

### Page Object Pattern

```ruby
# test/support/pages/posts_page.rb
class PostsPage
  include Capybara::DSL

  def visit_index
    visit posts_path
    self
  end

  def click_new_post
    click_on "New Post"
    PostFormPage.new
  end

  def has_post?(title)
    has_css?(".post", text: title)
  end

  def post_count
    all(".post").count
  end
end

# test/system/posts_test.rb
test "creates a new post" do
  sign_in users(:active_admin)

  posts_page = PostsPage.new.visit_index
  form_page = posts_page.click_new_post

  form_page.fill_title("My New Post")
  form_page.fill_body("Content here")
  form_page.submit

  assert posts_page.has_post?("My New Post")
end
```

### Testing JavaScript Interactions

```ruby
test "modal opens on button click", js: true do
  sign_in users(:active_admin)
  visit posts_path

  click_on "New Post"

  assert_selector "#post-modal", visible: true
  within "#post-modal" do
    assert_selector "h2", text: "New Post"
  end
end

test "form submits via AJAX", js: true do
  sign_in users(:active_admin)
  visit new_post_path

  fill_in "Title", with: "AJAX Post"
  fill_in "Body", with: "Content"

  click_on "Create Post"

  assert_text "Post was successfully created"
  assert_no_selector "#post-form"  # Form should disappear
  assert_selector ".post", text: "AJAX Post"
end
```

## Performance Testing

### Measuring Query Count

```ruby
test "index loads with minimal queries" do
  sign_in users(:active_admin)

  assert_queries_count(5) do  # Adjust expected count
    get posts_path
  end

  assert_response :success
end

test "show avoids N+1 queries" do
  post = posts(:post_with_many_comments)

  assert_queries_count(3) do
    get post_path(post)
  end
end
```

### Benchmarking

```ruby
test "search performs within acceptable time" do
  # Create test data if needed
  
  time = Benchmark.measure do
    100.times { Post.search("rails").to_a }
  end

  assert time.real < 1.0, "Search took #{time.real}s, expected < 1s"
end
```

## Parallel Testing

### Configuration

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  # Use threads for lighter parallelization
  # parallelize(workers: :number_of_processors, with: :threads)

  parallelize_setup do |worker|
    # Per-worker setup (e.g., separate search index)
  end

  parallelize_teardown do |worker|
    # Per-worker cleanup
  end
end
```

### Handling Shared Resources

```ruby
# For tests that can't run in parallel
class SequentialTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    # Manual cleanup needed
  end

  teardown do
    # Clean up manually
    Post.delete_all
  end
end
```

## Debugging Slow Tests

### Profiling

```bash
# Find slowest tests
bin/rails test --profile

# Profile specific file
bin/rails test test/models/user_test.rb --profile
```

### Common Causes

1. **Factory cascades** - Check for nested `create` calls
2. **Missing database indexes** - Check query plans
3. **Unnecessary callbacks** - Skip in test environment if safe
4. **External services** - Mock HTTP calls
5. **File I/O** - Use in-memory alternatives
6. **Complex queries** - Cache or simplify for tests

### Quick Fixes

```ruby
# Disable callbacks for specific tests
User.skip_callback(:save, :after, :send_welcome_email)

# Use transactions
self.use_transactional_tests = true

# Mock external services
stub_request(:post, "https://api.example.com/notify")
  .to_return(status: 200, body: "OK")

# Reduce BCrypt cost
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
```
