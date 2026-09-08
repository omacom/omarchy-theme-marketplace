---
name: active-storage
description: Expert guidance for Rails Active Storage — file uploads, attachments, image variants, direct uploads, and cloud service configuration. Use when working with file uploads, has_one_attached, has_many_attached, image processing, variants, S3/GCS/Azure storage, direct uploads, or file attachment patterns in Rails applications.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails active_storage:*), Bash(bin/rails db:migrate), Bash(bin/rails generate), Bash(bundle exec rails active_storage:*), Bash(bundle exec rails db:migrate)
---

# Rails Active Storage Expert

Implement file uploads, attachments, image processing, and cloud storage in Rails applications using Active Storage.

## Philosophy

**Core Principles:**
1. **Always run the install generator** — Active Storage needs its migrations and config
2. **Use libvips over ImageMagick** — 10x faster, 1/10 memory usage
3. **Prevent N+1 queries** — Always use `with_attached_<name>` scopes
4. **Handle missing attachments** — Never assume an attachment exists
5. **Proxy in production, redirect in development** — Proxy mode works with CDNs
6. **Use named variants** — Define variants on the model, not in views
7. **Tenanted SQLite apps** — `activerecord-tenanted` blobs 404 after save unless you follow `active-storage-multitenant`

## When To Use This Skill

- Adding file uploads to a Rails model
- Configuring cloud storage (S3, GCS, Azure)
- Implementing image resizing/transformation (variants)
- Setting up direct uploads from the browser
- Debugging attachment issues (missing files, broken variants)
- Migrating between storage services
- Testing file uploads
- Debugging 404s on saved images in an `activerecord-tenanted` app (switch to `active-storage-multitenant`)

## Instructions

### Step 1: Verify Setup

**ALWAYS check if Active Storage is installed first:**

```bash
# Check for Active Storage tables
bin/rails runner "puts ActiveStorage::Blob.table_exists?"

# Check for storage.yml
ls config/storage.yml

# Check for Active Storage migrations
ls db/migrate/*active_storage*
```

**If not installed:**

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

This creates three tables:
- `active_storage_blobs` — file metadata (filename, content_type, byte_size, checksum)
- `active_storage_attachments` — polymorphic join table connecting models to blobs
- `active_storage_variant_records` — tracks generated variants

**Verify image processing is available:**

```bash
# Check for libvips (preferred)
vips --version

# Or ImageMagick (fallback)
convert --version
```

Add to Gemfile if needed:

```ruby
gem "image_processing", "~> 1.2"  # Required for variants
```

### Step 2: Configure Storage Service

**config/storage.yml** — Define available services:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>
```

**Set the active service per environment:**

```ruby
# config/environments/development.rb
config.active_storage.service = :local

# config/environments/test.rb
config.active_storage.service = :test

# config/environments/production.rb
config.active_storage.service = :amazon  # or :google, :azure
```

For cloud services, see `reference.md` for S3, GCS, and Azure configuration.

### Step 3: Declare Attachments on Models

**Single file attachment:**

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

**Multiple file attachments:**

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

**With named variants (ALWAYS do this):**

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
    attachable.variant :large, resize_to_limit: [800, 800]
  end
end
```

**With a specific storage service:**

```ruby
class User < ApplicationRecord
  has_one_attached :avatar, service: :s3
end
```

### Step 4: Handle Attachments in Controllers

**Strong parameters — permit attachment params:**

```ruby
# has_one_attached
def user_params
  params.expect(user: [:name, :email, :avatar])
end

# has_many_attached
def message_params
  params.expect(message: [:title, :content, images: []])
end
```

**Attaching files programmatically:**

```ruby
# From an upload
user.avatar.attach(params[:avatar])

# From an IO object
user.avatar.attach(
  io: File.open("/path/to/file.jpg"),
  filename: "avatar.jpg",
  content_type: "image/jpeg"
)

# From a URL (download first)
user.avatar.attach(
  io: URI.open("https://example.com/photo.jpg"),
  filename: "photo.jpg"
)
```

### Step 5: Display Attachments in Views

**ALWAYS check if attached before rendering:**

```erb
<%# WRONG — will raise if no avatar %>
<%= image_tag user.avatar %>

<%# CORRECT — guard against missing attachment %>
<%= image_tag user.avatar if user.avatar.attached? %>

<%# BEST — use variant with guard %>
<% if user.avatar.attached? %>
  <%= image_tag user.avatar.variant(:thumb) %>
<% end %>
```

**Use named variants (not inline transforms):**

```erb
<%# WRONG — variant defined in view %>
<%= image_tag user.avatar.variant(resize_to_limit: [100, 100]) %>

<%# CORRECT — named variant from model %>
<%= image_tag user.avatar.variant(:thumb) %>
```

### Step 6: Prevent N+1 Queries

**This is the #1 performance mistake with Active Storage.**

```ruby
# WRONG — N+1 query for each user's avatar
@users = User.all
# In view: user.avatar triggers a query per user

# CORRECT — eager load attachments
@users = User.with_attached_avatar

# For has_many_attached
@messages = Message.with_attached_images
```

**When rendering variants, also load variant records:**

```ruby
# In view, after eager loading attachments:
message.images.with_all_variant_records.each do |image|
  image_tag image.variant(:thumb).processed.url
end
```

### Step 7: Form Setup

**Simple file upload:**

```erb
<%= form_with model: @user do |form| %>
  <%= form.file_field :avatar %>
  <%= form.submit %>
<% end %>
```

**Multiple files:**

```erb
<%= form_with model: @message do |form| %>
  <%= form.file_field :images, multiple: true %>
  <%= form.submit %>
<% end %>
```

**Preserve existing `has_many_attached` files on update:**

```erb
<%# Without this, updating replaces ALL existing attachments %>
<% @message.images.each do |image| %>
  <%= form.hidden_field :images, multiple: true, value: image.signed_id %>
<% end %>
<%= form.file_field :images, multiple: true %>
```

**Direct uploads (upload to cloud before form submit):**

```erb
<%= form.file_field :avatar, direct_upload: true %>
```

Requires Active Storage JavaScript. See `reference.md` for setup.

### Step 8: Removing Attachments

```ruby
# Synchronous — deletes blob + file from storage immediately
user.avatar.purge

# Async — deletes via background job (preferred in controllers)
user.avatar.purge_later
```

**Allow users to remove attachments via a checkbox:**

```erb
<% if @user.avatar.attached? %>
  <%= image_tag @user.avatar.variant(:thumb) %>
  <%= form.check_box :remove_avatar, label: "Remove avatar" %>
<% end %>
```

```ruby
# In controller or model
after_save :purge_avatar, if: -> { saved_change_to_attribute?(:remove_avatar) }

# Or handle in controller:
def update
  @user.update(user_params)
  @user.avatar.purge_later if params[:user][:remove_avatar] == "1"
end
```

### Step 9: Testing

**Use `file_fixture_upload` in integration tests:**

```ruby
class UsersControllerTest < ActionDispatch::IntegrationTest
  test "creates user with avatar" do
    post users_path, params: {
      user: {
        name: "Test",
        avatar: file_fixture_upload("avatar.png", "image/png")
      }
    }

    user = User.order(:created_at).last
    assert user.avatar.attached?
  end
end
```

**Place test files in `test/fixtures/files/`.**

**Clean up uploaded files after tests:**

```ruby
# test/test_helper.rb or application_system_test_case.rb
class ActionDispatch::IntegrationTest
  def after_teardown
    super
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
  end
end
```

**For parallel tests, isolate storage per process:**

```ruby
class ActiveSupport::TestCase
  parallelize_setup do |i|
    ActiveStorage::Blob.service.root = "#{ActiveStorage::Blob.service.root}-#{i}"
  end
end
```

See `reference.md` for fixture-based attachment testing.

## Common Agent Mistakes

### 1. Forgetting the install generator
Active Storage won't work without its migrations. Always run `bin/rails active_storage:install` and `bin/rails db:migrate`.

### 2. Missing image processing dependency
Variants require `gem "image_processing"` AND either libvips or ImageMagick installed on the system. Without these, `variant()` calls will raise.

### 3. Wrong variant processor syntax
```ruby
# WRONG — MiniMagick syntax with Vips processor
variant(resize: "100x100")

# CORRECT — Vips syntax (Rails 7+ default)
variant(resize_to_limit: [100, 100])
```

### 4. Not handling missing attachments
```ruby
# WILL RAISE if no avatar attached
user.avatar.variant(:thumb)

# SAFE
user.avatar.variant(:thumb) if user.avatar.attached?
```

### 5. N+1 queries with attachments
Always use `with_attached_<name>` scope when loading collections. This is the most common performance issue.

### 6. Defining variants in views instead of models
Variants defined inline in views are hard to maintain and can't be preprocessed. Define them on the model using the block syntax.

### 7. Replacing instead of appending with has_many_attached
By default, attaching new files to `has_many_attached` replaces all existing attachments. Use hidden fields with `signed_id` to preserve existing ones.

## Quick Reference

### Variant Transforms (Vips — Rails 7+ default)

| Transform | Syntax | Description |
|-----------|--------|-------------|
| Resize to fit | `resize_to_limit: [w, h]` | Shrinks to fit within bounds, preserves aspect ratio |
| Resize to fill | `resize_to_fill: [w, h]` | Fills bounds exactly, crops excess |
| Resize and pad | `resize_to_fit: [w, h]` | Fits within bounds, may be smaller |
| Resize exact | `resize_and_pad: [w, h]` | Fits within bounds, pads to exact size |
| Convert format | `format: :webp` | Convert to another format |
| Quality | `saver: { quality: 80 }` | Set output quality |
| Rotate | `rotate: 90` | Rotate by degrees |

### Key Methods

```ruby
# Attachment status
record.avatar.attached?        # => true/false
record.avatar.blank?           # => true/false (opposite of attached?)

# File metadata
record.avatar.filename         # => "avatar.png"
record.avatar.content_type     # => "image/png"
record.avatar.byte_size        # => 12345
record.avatar.blob.metadata    # => {"identified"=>true, "width"=>100, "height"=>100, "analyzed"=>true}

# URLs
url_for(record.avatar)                    # Redirect URL
rails_blob_path(record.avatar)            # Path helper
rails_storage_proxy_path(record.avatar)   # Proxy URL

# Downloading
record.avatar.download         # => binary string
record.avatar.open { |f| ... } # => yields Tempfile

# Purging
record.avatar.purge            # Sync delete
record.avatar.purge_later      # Async delete
```

### Configuration Options

```ruby
# config/application.rb or environment files
config.active_storage.variant_processor = :vips          # :vips (default) or :mini_magick
config.active_storage.resolve_model_to_route = :rails_storage_proxy  # Enable proxy mode
config.active_storage.draw_routes = false                # Disable default routes (for custom auth)
config.active_storage.track_variants = true              # Track variant records (default)
config.active_storage.service = :local                   # Set storage service
```
