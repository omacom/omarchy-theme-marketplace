# Generator Testing, Edge Cases, Recipes, and Troubleshooting

Testing custom generators, handling edge cases, common generator recipes, and troubleshooting.

## Generator Testing

### Test Structure

```ruby
# test/lib/generators/service_generator_test.rb
require "test_helper"
require "generators/service/service_generator"

class ServiceGeneratorTest < Rails::Generators::TestCase
  tests ServiceGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "creates service file" do
    run_generator ["user_signup"]
    assert_file "app/services/user_signup_service.rb" do |content|
      assert_match(/class UserSignupService/, content)
      assert_match(/def call/, content)
    end
  end

  test "creates test file" do
    run_generator ["user_signup"]
    assert_file "test/services/user_signup_service_test.rb" do |content|
      assert_match(/class UserSignupServiceTest/, content)
    end
  end

  test "respects --skip-test flag" do
    run_generator ["user_signup", "--skip-test"]
    assert_no_file "test/services/user_signup_service_test.rb"
  end

  test "handles namespaced names" do
    run_generator ["admin/user_cleanup"]
    assert_file "app/services/admin/user_cleanup_service.rb" do |content|
      assert_match(/module Admin/, content)
      assert_match(/class UserCleanupService/, content)
    end
  end
end
```

### Available Test Assertions

```ruby
# File existence
assert_file "path/to/file.rb"
assert_no_file "path/to/file.rb"
assert_directory "app/services"

# File content
assert_file "path/to/file.rb" do |content|
  assert_match(/expected_pattern/, content)
  assert_instance_of String, content
end

# File content (shorthand)
assert_file "path/to/file.rb", /class MyService/

# Migration existence (handles timestamps)
assert_migration "db/migrate/create_posts.rb"
assert_migration "db/migrate/create_posts.rb" do |content|
  assert_match(/t.string :title/, content)
end

# Route assertions
assert_file "config/routes.rb", /resources :posts/
```

### Running Generator Tests

```bash
# Run specific generator test
RAILS_LOG_TO_STDOUT=true bin/rails test test/lib/generators/service_generator_test.rb

# Run all generator tests
RAILS_LOG_TO_STDOUT=true bin/rails test test/lib/generators/
```

---

## Edge Cases and Gotchas

### Namespaced Models

```bash
# Creates Admin::User model
bin/rails g model Admin::User name email

# Files created:
# app/models/admin.rb (module)
# app/models/admin/user.rb
# db/migrate/..._create_admin_users.rb
# test/models/admin/user_test.rb
# test/fixtures/admin/users.yml
```

### STI (Single Table Inheritance)

```bash
# Create base model
bin/rails g model Vehicle type name

# Create STI subclasses (no migration needed)
bin/rails g model Car --parent=Vehicle
bin/rails g model Truck --parent=Vehicle
```

### API-Only Applications

In API-only apps (`config.api_only = true`):
- Scaffold generates API controllers (no views)
- No helper generation
- JSON responses by default
- `--api` flag is implicit

### UUID Primary Keys

```ruby
# config/application.rb
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end

# Also need in config/initializers/generators.rb or migration:
# enable_extension 'pgcrypto' (PostgreSQL)
```

### Multi-Database

```bash
# Generate migration for specific database
bin/rails g migration AddNameToAnimals name --database=animals

# Generate model for specific database
bin/rails g model Dog name --database=animals
```

### Token Attributes

```bash
bin/rails g model User token:token
# Generates: has_secure_token in model

bin/rails g model User auth_token:token
# Generates: has_secure_token :auth_token
```

### Password Digest

```bash
bin/rails g model User password:digest
# Generates: has_secure_password in model
# Adds password_digest string column to migration
# Adds bcrypt gem to Gemfile
```

### Rich Text (Action Text)

```bash
bin/rails g model Article title body:rich_text
# Note: rich_text type doesn't create a column
# It adds has_rich_text :body to the model
```

### Attachments (Active Storage)

```bash
bin/rails g model User avatar:attachment
bin/rails g model Product images:attachments
# Adds has_one_attached :avatar or has_many_attached :images
```

---

## Recipes: Common Generator Patterns

### Service Object Generator

```bash
bin/rails g generator service
```

```ruby
# lib/generators/service/service_generator.rb
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_service
    template "service.rb.tt", "app/services/#{file_path}_service.rb"
  end

  def create_test
    template "service_test.rb.tt", "test/services/#{file_path}_service_test.rb"
  end
end
```

### Form Object Generator

```ruby
# lib/generators/form/form_generator.rb
class FormGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  def create_form
    template "form.rb.tt", "app/forms/#{file_path}_form.rb"
  end

  def create_test
    template "form_test.rb.tt", "test/forms/#{file_path}_form_test.rb"
  end
end
```

### Query Object Generator

```ruby
# lib/generators/query/query_generator.rb
class QueryGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_query
    template "query.rb.tt", "app/queries/#{file_path}_query.rb"
  end

  def create_test
    template "query_test.rb.tt", "test/queries/#{file_path}_query_test.rb"
  end
end
```

---

## Troubleshooting

### "Could not find generator"

```bash
# Check available generators
bin/rails g --help

# Check if the gem providing the generator is installed
bundle list | grep generator_gem_name

# Check load path
bin/rails runner "puts $LOAD_PATH"
```

### "Another migration is already named"

```bash
# Check existing migrations
ls db/migrate/*create_posts*

# Use a different name or destroy first
bin/rails d migration CreatePosts
bin/rails g migration CreatePosts title:string
```

### Generated File Has Wrong Content

```bash
# Check for template overrides
find lib/templates -name "*.tt" 2>/dev/null

# Check generator config
grep -A 20 "config.generators" config/application.rb

# Use --pretend to see what would happen
bin/rails g model Post title --pretend
```

### Scaffold Generating Too Many Files

```ruby
# Add to config/application.rb
config.generators do |g|
  g.helper false
  g.assets false
  g.jbuilder false
  g.system_tests nil
end
```

Then scaffold only generates what you actually need.
