# Complete Built-In Generator Reference

All Rails built-in generators with flags, file outputs, and customization options.

## model

Creates model class, migration, test, and fixture.

```bash
bin/rails g model User name email:string:uniq age:integer admin:boolean

# With references
bin/rails g model Comment body:text post:references user:references

# With polymorphic reference
bin/rails g model Comment body:text commentable:references{polymorphic}

# With specific index
bin/rails g model Product name sku:string:uniq price:decimal{8,2}

# Skip migration (model class only)
bin/rails g model Calculation --skip-migration

# With namespace
bin/rails g model Admin::User name email
# Creates: app/models/admin/user.rb, db/migrate/..._create_admin_users.rb

# With parent class (STI)
bin/rails g model AdminUser --parent=User
# Creates model inheriting from User, no migration
```

**Files created:**
- `app/models/[name].rb`
- `db/migrate/TIMESTAMP_create_[table].rb`
- `test/models/[name]_test.rb`
- `test/fixtures/[table].yml`

**Common flags:**
| Flag | Effect |
|------|--------|
| `--skip-migration` | No migration file |
| `--no-test-framework` | No test or fixture |
| `--no-fixture` | No fixture file |
| `--primary-key-type=uuid` | UUID primary key |
| `--parent=ClassName` | STI — inherit from parent, skip migration |
| `--database=animals` | Multi-DB: generate for specific database |

---

## migration

Creates a standalone migration file. The migration name determines content.

```bash
# Add columns — name pattern: AddXxxToYyy
bin/rails g migration AddEmailToUsers email:string
# => def change; add_column :users, :email, :string; end

bin/rails g migration AddIndexToUsersEmail
# => empty change (no columns specified, just the name)

bin/rails g migration AddDetailsToProducts price:decimal{8,2} supplier:references
# => adds both columns

# Remove columns — name pattern: RemoveXxxFromYyy
bin/rails g migration RemoveAgeFromUsers age:integer
# => def change; remove_column :users, :age, :integer; end

# Create table — name pattern: CreateXxx
bin/rails g migration CreateProducts name:string price:decimal
# => create_table with those columns

# Create join table — name pattern: CreateJoinTableXxxYyy
bin/rails g migration CreateJoinTableProductsCategories products categories
# => create_join_table :products, :categories

# Generic name (empty change method)
bin/rails g migration ConsolidateUserData
# => empty def change; end — fill in manually
```

**Name pattern inference rules:**
| Pattern | Inferred Action |
|---------|----------------|
| `AddXxxToYyy field:type` | `add_column :yyy, :field, :type` |
| `RemoveXxxFromYyy field:type` | `remove_column :yyy, :field, :type` |
| `CreateXxx field:type` | `create_table` with columns |
| `CreateJoinTableXxxYyy` | `create_join_table` |
| Anything else | Empty `change` method |

**Column modifiers in migration generator:**
```bash
name:string{40}              # limit: 40
price:decimal{10,2}          # precision: 10, scale: 2
email:string:index           # adds add_index
slug:string:uniq             # adds add_index unique: true
user:references              # adds foreign key + belongs_to
commentable:references{polymorphic}  # polymorphic reference
```

---

## controller

Creates controller, views, route entries, test, and helper.

```bash
bin/rails g controller Posts index show new create

# Namespaced
bin/rails g controller Admin::Posts index show

# API-only (no views)
bin/rails g controller Api::V1::Posts index show --no-helper --skip-routes
```

**Files created:**
- `app/controllers/[name]_controller.rb` (with empty action methods)
- `app/views/[name]/[action].html.erb` (for each action)
- `test/controllers/[name]_controller_test.rb`
- `app/helpers/[name]_helper.rb`
- Route entries for each action

**Common flags:**
| Flag | Effect |
|------|--------|
| `--no-helper` | Skip helper file |
| `--skip-routes` | Don't add routes |
| `--no-test-framework` | Skip test file |
| `--api` | Skip views and helpers |

**Key difference from scaffold:** Controller generator creates individual route entries (`get 'posts/index'`), NOT `resources :posts`. Use `resource` or `scaffold` for RESTful routes.

---

## scaffold

Creates everything for a full CRUD resource.

```bash
bin/rails g scaffold Post title body:text published:boolean user:references

# API-only (no views, no view tests)
bin/rails g scaffold Post title body:text --api

# With specific test framework
bin/rails g scaffold Post title --test-framework=rspec

# With UUID primary keys
bin/rails g scaffold Post title --primary-key-type=uuid
```

**Files created:**
- Model + migration + fixture
- Controller with all 7 RESTful actions
- Views (index, show, new, edit, _form, _resource)
- Route (`resources :posts`)
- Helper
- Test files (controller + system)
- Jbuilder templates (if jbuilder is present)

**Common flags:**
| Flag | Effect |
|------|--------|
| `--api` | API-only (no views, no helpers) |
| `--no-helper` | Skip helper |
| `--no-jbuilder` | Skip JSON builder views |
| `--no-assets` | Skip asset files |
| `--no-test-framework` | Skip all tests |
| `--force` | Overwrite existing files |

---

## resource

Like scaffold but generates an **empty** controller (no actions, no views).

```bash
bin/rails g resource Post title body:text
```

**Creates:** model + migration + empty controller + `resources :posts` route + test + fixture

**Use when:** You want the model, route, and controller file but will write controller actions yourself.

---

## scaffold_controller

Creates controller + views for an **existing** model. No model or migration.

```bash
bin/rails g scaffold_controller Post title body:text

# API-only
bin/rails g scaffold_controller Post title body:text --api

# Specify model name explicitly
bin/rails g scaffold_controller Admin::Post title body:text
```

**Use when:** Model already exists (maybe from a previous `bin/rails g model`), and you now need the controller + views.

---

## job

```bash
bin/rails g job ProcessPayment

# With queue name
bin/rails g job ProcessPayment --queue=payments
```

**Creates:**
- `app/jobs/process_payment_job.rb`
- `test/jobs/process_payment_job_test.rb`

---

## mailer

```bash
bin/rails g mailer UserMailer welcome password_reset

# Namespaced
bin/rails g mailer Admin::NotificationMailer alert digest
```

**Creates:**
- `app/mailers/user_mailer.rb` (with methods for each action)
- `app/views/user_mailer/welcome.html.erb`
- `app/views/user_mailer/welcome.text.erb`
- `app/views/user_mailer/password_reset.html.erb`
- `app/views/user_mailer/password_reset.text.erb`
- `test/mailers/user_mailer_test.rb`
- `test/mailers/previews/user_mailer_preview.rb`

---

## channel (Action Cable)

```bash
bin/rails g channel Chat speak

bin/rails g channel Notifications
```

**Creates:**
- `app/channels/chat_channel.rb`
- `test/channels/chat_channel_test.rb`

---

## mailbox (Action Mailbox)

```bash
bin/rails g mailbox Forwards
```

**Creates:**
- `app/mailboxes/forwards_mailbox.rb`
- `test/mailboxes/forwards_mailbox_test.rb`

---

## task (Rake)

```bash
bin/rails g task data_migration migrate_users cleanup_orphans
```

**Creates:**
- `lib/tasks/data_migration.rake` (with `data_migration:migrate_users` and `data_migration:cleanup_orphans` tasks)

---

## integration_test / system_test

```bash
bin/rails g integration_test UserRegistration
bin/rails g system_test UserRegistration
```

**Creates:** Test file in `test/integration/` or `test/system/`.

---

## helper

```bash
bin/rails g helper Posts
```

**Creates:** `app/helpers/posts_helper.rb` + test.

---

## generator

Creates a custom generator skeleton.

```bash
bin/rails g generator service

# Namespaced (for overriding Rails generators)
bin/rails g generator rails/my_helper
```

**Creates:**
- `lib/generators/service/service_generator.rb`
- `lib/generators/service/USAGE`
- `lib/generators/service/templates/`
- `test/lib/generators/service_generator_test.rb`

---

## Customizing Generator Defaults

### config.generators

Set in `config/application.rb` to change defaults for ALL generator invocations:

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    config.generators do |g|
      # ORM settings
      g.orm :active_record, primary_key_type: :uuid

      # Test framework
      g.test_framework :test_unit, fixture: true
      # Or: g.test_framework :rspec, fixture: true
      # Or: g.test_framework nil  # disable test generation

      # Template engine
      g.template_engine :erb
      # Or: g.template_engine :slim
      # Or: g.template_engine :haml

      # Skip files globally
      g.helper false
      g.assets false
      g.stylesheets false
      g.javascripts false
      g.jbuilder false
      g.system_tests nil

      # Custom frameworks
      g.scaffold_controller :scaffold_controller
      g.resource_route :resource_route
    end
  end
end
```

### Per-Environment Generator Config

```ruby
# config/environments/development.rb
config.generators do |g|
  g.test_framework nil  # Skip tests in development generators
end
```

### Checking Current Config

```bash
# From Rails console
rails runner "pp Rails.application.config.generators"

# Or grep config files
grep -rn "config.generators" config/
```
