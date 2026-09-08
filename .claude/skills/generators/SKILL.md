---
name: generators
description: Expert guidance for using and creating Rails generators. Use when running "rails generate", "rails g", scaffolding resources, generating models, controllers, migrations, mailers, jobs, or any generated code. Also use for creating custom generators, customizing generator defaults, overriding generator templates, or configuring config.generators. Covers all built-in generators, their flags, and when to use (or not use) each one.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate*), Bash(bin/rails g*), Bash(bin/rails destroy*), Bash(bin/rails d*)
---

# Rails Generators Expert

Use the right generator with the right flags. Generate exactly what you need — nothing more.

## Philosophy

**Core Principles:**
1. **Generate the minimum** — Use `model` when you need a model, not `scaffold`. Use `migration` when you need a migration, not `model`.
2. **Skip what you won't use** — Pass `--no-helper`, `--no-assets`, `--no-jbuilder` unless explicitly needed (or configure defaults in `config.generators`).
3. **Know your generators** — Rails has 30+ built-in generators. Learn them before writing code by hand.
4. **Check project defaults first** — Read `config/application.rb` for `config.generators` before running anything.
5. **Destroy before regenerating** — Use `bin/rails destroy` to cleanly undo a generator before re-running with different options.

## When To Use This Skill

- Running any `bin/rails generate` command
- Deciding which generator fits the task
- Customizing generator defaults in `config/application.rb`
- Creating custom generators for project-specific patterns
- Overriding built-in generator templates
- Understanding what files a generator will create

## Instructions

### Step 1: Check Project Generator Config

**Check existing generator configuration first** — the project may already skip helpers, use UUIDs, or set other defaults:

```bash
# Check for custom generator config
grep -A 20 "config.generators" config/application.rb

# See all available generators
bin/rails generate --help

# See specific generator options
bin/rails generate model --help
```

Match project conventions. If the project disables helpers or uses UUIDs, your generators should too.

### Step 2: Choose the Right Generator

Pick the **most specific** generator that does what you need:

| Need | Generator | NOT |
|------|-----------|-----|
| Database column change | `migration` | `model` |
| New model with table | `model` | `scaffold` |
| New controller + views | `controller` | `scaffold` |
| Full CRUD resource | `scaffold` | — |
| API-only resource | `scaffold --api` | `scaffold` |
| Background job | `job` | Writing by hand |
| Mailer | `mailer` | Writing by hand |
| Database table change | `migration` | Writing by hand |

**The Generator Hierarchy (most → least specific):**
```
migration → model → resource → scaffold
                  ↗
controller ------/
```

Each level adds more files. Always pick the lowest level that satisfies the requirement.

### Step 3: Use the Right Flags

**Essential flags to know:**

```bash
# Skip unwanted files
--no-helper          # Skip helper file (almost always want this)
--no-assets          # Skip CSS/JS files
--no-jbuilder        # Skip JSON builder views
--no-test-framework  # Skip test files (if writing tests separately)
--no-fixture         # Skip fixture file only

# Control behavior
--skip-migration     # Generate model without migration
--skip-routes        # Don't add to routes.rb
--force              # Overwrite existing files
--pretend            # Dry run — show what would happen

# Field types
title:string         # Default type, can omit :string
body:text            # Long text
price:decimal        # Decimal number
published:boolean    # Boolean
published_at:datetime # Timestamp
user:references      # Foreign key + belongs_to
tags:jsonb           # JSON column (PostgreSQL)
```

### Step 4: Run with --pretend First

**For any generator that creates multiple files, dry-run first** — it's easier to verify than to clean up:

```bash
# See what would be created without creating it
bin/rails generate scaffold Post title body:text --pretend
```

This prevents generating unwanted files you'll have to clean up.

### Step 5: Destroy Before Regenerating

If you made a mistake, **destroy first**:

```bash
# Undo a generator completely
bin/rails destroy model Post
bin/rails destroy scaffold Post
bin/rails destroy controller Posts
```

`destroy` removes exactly what `generate` created. Don't manually delete files.

### Step 6: Configure Defaults

**Set project-wide defaults in `config/application.rb`:**

```ruby
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
  g.test_framework :test_unit, fixture: true
  g.helper false                    # Never generate helpers
  g.assets false                    # Never generate assets
  g.jbuilder false                  # Never generate jbuilder views
  g.system_tests :test_unit         # Or nil to skip
  g.template_engine :erb            # Or :slim, :haml
  g.stylesheets false               # Skip stylesheets
  g.javascripts false               # Skip JS files
end
```

Once configured, you don't need `--no-helper` etc. on every command.

## Built-In Generators Quick Reference

### Most Used

| Generator | Creates | Example |
|-----------|---------|---------|
| `model` | Model + migration + test + fixture | `bin/rails g model Post title body:text` |
| `migration` | Migration file only | `bin/rails g migration AddSlugToPosts slug:string:uniq` |
| `controller` | Controller + views + test + route + helper | `bin/rails g controller Posts index show` |
| `scaffold` | Model + controller + views + migration + tests + routes | `bin/rails g scaffold Post title body:text` |
| `resource` | Model + controller (empty) + migration + route | `bin/rails g resource Post title body:text` |

### Other Built-In

| Generator | Creates | Example |
|-----------|---------|---------|
| `job` | Job class + test | `bin/rails g job ProcessPayment` |
| `mailer` | Mailer + views + test | `bin/rails g mailer UserMailer welcome reset_password` |
| `channel` | Action Cable channel + JS | `bin/rails g channel Chat speak` |
| `task` | Rake task | `bin/rails g task feeds fetch` |
| `mailbox` | Action Mailbox mailbox + test | `bin/rails g mailbox Forwards` |
| `generator` | Custom generator skeleton | `bin/rails g generator my_generator` |
| `integration_test` | Integration test file | `bin/rails g integration_test UserFlows` |
| `system_test` | System test file | `bin/rails g system_test UserFlows` |
| `scaffold_controller` | Controller + views (no model/migration) | `bin/rails g scaffold_controller Post title body:text` |
| `helper` | Helper module + test | `bin/rails g helper Posts` |

### Migration Name Conventions

Rails infers migration behavior from the name:

```bash
# Add columns (AddXxxToYyy)
bin/rails g migration AddSlugToPosts slug:string:uniq

# Remove columns (RemoveXxxFromYyy)
bin/rails g migration RemoveBodyFromPosts body:text

# Create join table (CreateJoinTableXxxYyy)
bin/rails g migration CreateJoinTablePostsCategories posts categories

# Standalone (no inference — empty change method)
bin/rails g migration UpdatePostsSchema
```

### Field Type Reference

```bash
# Common types
string        # VARCHAR (255 default)
text          # TEXT (unlimited)
integer       # INT
float         # FLOAT
decimal       # DECIMAL (use for money)
boolean       # BOOLEAN
date          # DATE
datetime      # DATETIME
timestamp     # TIMESTAMP
time          # TIME
binary        # BLOB

# Special types
references    # Foreign key (adds _id column + index + belongs_to)
belongs_to    # Alias for references
jsonb         # JSONB (PostgreSQL)
json          # JSON
uuid          # UUID
inet          # INET (PostgreSQL)
citext        # Case-insensitive text (PostgreSQL)

# Modifiers
title:string{100}        # String with limit
price:decimal{8,2}       # Precision and scale
slug:string:uniq         # Add unique index
slug:string:index        # Add index
user:references{polymorphic}  # Polymorphic association
```

## Creating Custom Generators

### When to Create One

Create a custom generator when your project has repeating patterns:
- Service objects with consistent structure
- Form objects
- Query objects
- Policy classes
- Decorators/presenters

### How to Create

```bash
bin/rails generate generator service
```

Creates:
```
lib/generators/service/
├── service_generator.rb
├── USAGE
└── templates/
```

### Generator Anatomy

```ruby
# lib/generators/service/service_generator.rb
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  # Optional: add arguments and options
  class_option :async, type: :boolean, default: false,
    desc: "Generate an async service with ActiveJob"

  def create_service_file
    template "service.rb.tt", "app/services/#{file_name}_service.rb"
  end

  def create_test_file
    template "service_test.rb.tt", "test/services/#{file_name}_service_test.rb"
  end

  private

  def async?
    options[:async]
  end
end
```

### Template Files

```ruby
# lib/generators/service/templates/service.rb.tt
class <%= class_name %>Service
  def initialize(<%= file_name %>)
    @<%= file_name %> = <%= file_name %>
  end

  def call
    # TODO: implement
  end

  private

  attr_reader :<%= file_name %>
end
```

### Available Template Variables

| Variable | Example Input | Result |
|----------|--------------|--------|
| `name` | `admin/user_cleanup` | `admin/user_cleanup` |
| `file_name` | `admin/user_cleanup` | `user_cleanup` |
| `class_name` | `admin/user_cleanup` | `Admin::UserCleanup` |
| `human_name` | `admin/user_cleanup` | `Admin user cleanup` |
| `plural_name` | `user` | `users` |
| `singular_name` | `users` | `user` |
| `table_name` | `user` | `users` |
| `file_path` | `admin/user_cleanup` | `admin/user_cleanup` |
| `class_path` | `admin/user_cleanup` | `["admin"]` |

## Overriding Built-In Templates

Override any built-in generator's templates by placing files in `lib/templates/`:

```
lib/templates/
├── erb/
│   └── scaffold/
│       ├── index.html.erb.tt
│       ├── show.html.erb.tt
│       ├── _form.html.erb.tt
│       └── _resource.html.erb.tt
├── rails/
│   └── scaffold_controller/
│       └── controller.rb.tt
└── active_record/
    └── migration/
        └── create_table_migration.rb.tt
```

Rails checks `lib/templates/` before its own templates. No config needed.

**Template escaping:** Generator templates that produce ERB need double escaping:
- `<%%=` in template → `<%=` in output
- `<%=` in template → evaluated at generation time

## Common Agent Mistakes

1. **Using `scaffold` when `model` suffices** — Scaffold creates controller, views, routes, helpers, and tests. If you only need a model, use `model` — less cleanup, less noise.

2. **Forgetting `--no-helper`** — Helper files are rarely used in modern Rails. Generating them just adds clutter.

3. **Skipping `--pretend`** — Dry-running complex generators takes a second and prevents generating files you'll have to manually clean up.

4. **Writing migrations by hand** — `bin/rails g migration` with naming conventions (AddXxxToYyy, RemoveXxxFromYyy) auto-generates the body. Save the typing.

5. **Generating then manually deleting files** — Use `bin/rails destroy` instead. It cleanly reverts route additions and removes all generated files.

6. **Not knowing about `scaffold_controller`** — When you have a model but need controller+views, use `scaffold_controller`. Running `scaffold` would try to recreate the model.

7. **Ignoring project defaults** — Check `config.generators` first. The project may already skip helpers, making `--no-helper` redundant.

8. **Creating custom generators for one-offs** — Custom generators pay off when you repeat a pattern 3+ times. For one-offs, just write the files.

## Performance Tips

- **`--pretend` is free** — Always use it to verify before generating
- **Batch field definitions** — `bin/rails g model Post title body:text published:boolean` is one migration, not three
- **Use `migration` for schema changes** — Don't generate a new model to add a column

## Running Generators

```bash
# Standard
bin/rails generate model Post title body:text
bin/rails g model Post title body:text          # Short alias

# Dry run
bin/rails g model Post title --pretend

# Destroy (undo)
bin/rails destroy model Post
bin/rails d model Post                          # Short alias

# List all available
bin/rails generate --help

# Generator-specific help
bin/rails g model --help
bin/rails g migration --help
bin/rails g scaffold --help
```

## Debugging Generators

```bash
# See what a generator would do
bin/rails g model Post --pretend

# Check generator resolution path
bin/rails g model --help | head -5

# Find where templates live
find lib/templates -name "*.tt" 2>/dev/null
find $(bundle show railties)/lib/rails/generators -name "*.tt" | head -20

# Check current generator config
grep -A 20 "config.generators" config/application.rb
```

## Detailed Reference

See the `references/` directory for complete examples and edge cases:
- `references/built-in-generators.md` — All built-in generators with flags, files created, and customizing defaults
- `references/custom-generators.md` — Creating custom generators, hooks/composition, resolution order
- `references/templates.md` — Overriding built-in templates, application templates for `rails new`
- `references/thor-actions.md` — Thor file manipulation methods (create_file, inject_into_file, gsub_file, etc.)
- `references/testing.md` — Generator testing, edge cases (STI, UUID, namespaces), recipes, troubleshooting
