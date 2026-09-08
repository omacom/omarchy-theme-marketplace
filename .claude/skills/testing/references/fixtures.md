# Fixture Strategies

Detailed patterns for using fixtures effectively in Rails tests.

---

## Fixtures vs Factories — The Definitive Answer

**Use fixtures (Rails default).** Here's why:

| Factor | Fixtures | Factory Bot |
|--------|----------|-------------|
| Speed | Loaded once via transaction | Created per test |
| Data consistency | Same data every run | Random/sequential |
| Association handling | Reference by name | Cascading creation |
| Test isolation | Shared read, transactional write | Fully isolated |
| Setup time | Near zero | Linear with test count |
| Debugging | Known data, inspectable | Generated, harder to trace |

## When Factories Might Be Acceptable

- Truly dynamic data requirements (rare)
- When the project already uses Factory Bot extensively (don't rewrite)
- Combinatorial testing with many attribute variations

## Fixture Tips

```yaml
# test/fixtures/users.yml

# Use ERB for dynamic values
admin:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "admin") %>
  email: "admin@example.com"
  name: "Admin User"
  password_digest: <%= BCrypt::Password.create("password", cost: 1) %>
  admin: true
  created_at: <%= 1.year.ago %>

regular:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "regular") %>
  email: "regular@example.com"
  name: "Regular User"
  password_digest: <%= BCrypt::Password.create("password", cost: 1) %>
  admin: false

# Reference associations by name, not ID
# test/fixtures/articles.yml
published:
  title: "Published Article"
  body: "This is published."
  author: admin          # References users(:admin)
  published_at: <%= 1.day.ago %>
  status: published

draft:
  title: "Draft Article"
  body: "Work in progress."
  author: regular
  status: draft
```

## File Fixtures

```ruby
# test/fixtures/files/sample.csv
# test/fixtures/files/avatar.png
# test/fixtures/files/document.pdf

# Access in tests:
file_fixture("sample.csv")         # Returns Pathname
file_fixture("sample.csv").read    # Read contents
```

## Active Storage Fixtures

```yaml
# test/fixtures/active_storage/blobs.yml
avatar_blob: <%= ActiveStorage::FixtureSet.blob(
  filename: "avatar.png",
  content_type: "image/png"
) %>

# test/fixtures/active_storage/attachments.yml
admin_avatar:
  name: avatar
  record: admin (User)
  blob: avatar_blob
```

## Test Helper Configuration

### Minimal `test_helper.rb`

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Auto-require all support files
Dir[Rails.root.join("test", "support", "**", "*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
```

### Shared Test Helpers

Organize helpers in `test/support/`:

```ruby
# test/support/authentication_helper.rb
module AuthenticationHelper
  def sign_in_as(user, password: "password")
    post session_url, params: { email: user.email, password: password }
    assert_response :redirect
    follow_redirect!
  end

  def sign_out
    delete session_url
  end
end

# Include in integration/request tests
class ActionDispatch::IntegrationTest
  include AuthenticationHelper
end
```

```ruby
# test/support/json_helper.rb
module JsonHelper
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def json_body
    response.parsed_body
  end
end

class ActionDispatch::IntegrationTest
  include JsonHelper
end
```

### Test Environment Config

```ruby
# config/environments/test.rb

Rails.application.configure do
  config.eager_load = ENV["CI"].present?

  # Speed up password hashing
  config.active_model.min_cost_bcrypt = true  # Rails 8+
  # Or for older Rails:
  # BCrypt::Engine.cost = 1

  # Raise on missing translations
  config.i18n.raise_on_missing_translations = true

  # Raise on missing callback actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Disable logging for speed (or set to :warn)
  config.logger = Logger.new(nil)
  config.log_level = :fatal

  # Active Job uses test adapter by default
  config.active_job.queue_adapter = :test

  # Raise errors for missing template variables
  config.action_view.raise_on_missing_translations = true
end
```

## Test Database Strategies

### Schema Loading

```bash
# Prepare test DB from schema.rb/structure.sql
bin/rails db:test:prepare

# Rebuild completely (drop + create + load schema)
bin/rails db:test:purge
bin/rails db:test:prepare

# Or in one command
RAILS_ENV=test bin/rails db:reset
```

### Multiple Databases

```ruby
# config/database.yml
test:
  primary:
    <<: *default
    database: myapp_test
  cache:
    <<: *default
    database: myapp_test_cache
    migrations_paths: db/cache_migrate
```

Rails wraps each database in its own transaction during tests.

### Seed Data in Tests

```ruby
# Generally avoid seeds in tests — use fixtures instead
# But if you must:
class ActiveSupport::TestCase
  setup do
    # Only if absolutely necessary
    Rails.application.load_seed if SomeModel.count.zero?
  end
end
```
