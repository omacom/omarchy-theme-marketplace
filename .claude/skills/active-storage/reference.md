# Active Storage Reference

Detailed patterns, configuration examples, and edge cases for Rails Active Storage.

## Table of Contents
- [Cloud Service Configuration](#cloud-service-configuration)
- [Variant Processing Deep Dive](#variant-processing-deep-dive)
- [Previews (Non-Image Files)](#previews-non-image-files)
- [Direct Uploads](#direct-uploads)
- [Querying Attachments](#querying-attachments)
- [Serving Files](#serving-files)
- [Attaching File/IO Objects](#attaching-fileio-objects)
- [Downloading Files](#downloading-files)
- [Purging Unattached Uploads](#purging-unattached-uploads)
- [Analyzers](#analyzers)
- [Testing Patterns](#testing-patterns)
- [Content Type Validation](#content-type-validation)
- [Custom Metadata](#custom-metadata)
- [Edge Cases & Gotchas](#edge-cases--gotchas)

## Cloud Service Configuration

### Amazon S3

**Gemfile:**
```ruby
gem "aws-sdk-s3", require: false
```

**config/storage.yml:**
```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: myapp-<%= Rails.env %>
```

**With additional options:**
```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: myapp-<%= Rails.env %>
  http_open_timeout: 5
  http_read_timeout: 5
  retry_limit: 3
  upload:
    server_side_encryption: "AES256"
    cache_control: "private, max-age=<%= 1.day.to_i %>"
```

**Required S3 permissions:** `s3:ListBucket`, `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`.
For public access, also need `s3:PutObjectAcl`.

**Using IAM/environment credentials (no keys in config):**
```yaml
amazon:
  service: S3
  region: us-east-1
  bucket: myapp-<%= Rails.env %>
  # Omit access_key_id and secret_access_key — uses IAM role, env vars, or ~/.aws/credentials
```

**S3-compatible services (DigitalOcean Spaces, MinIO, etc.):**
```yaml
digitalocean:
  service: S3
  endpoint: https://nyc3.digitaloceanspaces.com
  access_key_id: <%= Rails.application.credentials.dig(:digitalocean, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:digitalocean, :secret_access_key) %>
  bucket: myapp-<%= Rails.env %>
  region: nyc3
```

### Google Cloud Storage

**Gemfile:**
```ruby
gem "google-cloud-storage", "~> 1.11", require: false
```

**config/storage.yml:**
```yaml
google:
  service: GCS
  credentials: <%= Rails.root.join("path/to/keyfile.json") %>
  project: my-project-id
  bucket: myapp-<%= Rails.env %>
```

**With inline credentials:**
```yaml
google:
  service: GCS
  credentials:
    type: "service_account"
    project_id: "my-project"
    private_key_id: <%= Rails.application.credentials.dig(:gcs, :private_key_id) %>
    private_key: <%= Rails.application.credentials.dig(:gcs, :private_key).dump %>
    client_email: "storage@my-project.iam.gserviceaccount.com"
    client_id: "123456789"
    auth_uri: "https://accounts.google.com/o/oauth2/auth"
    token_uri: "https://accounts.google.com/o/oauth2/token"
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
    client_x509_cert_url: ""
  project: my-project
  bucket: myapp-<%= Rails.env %>
```

**With IAM signing (for Workload Identity on GKE):**
```yaml
google:
  service: GCS
  project: my-project
  bucket: myapp-<%= Rails.env %>
  iam: true
  gsa_email: "storage@my-project.iam.gserviceaccount.com"
```

### Azure Storage

**Gemfile:**
```ruby
gem "azure-storage-blob", "~> 2.0", require: false
```

**config/storage.yml:**
```yaml
azure:
  service: AzureStorage
  storage_account_name: myapp
  storage_access_key: <%= Rails.application.credentials.dig(:azure, :storage_access_key) %>
  container: myapp-<%= Rails.env %>
```

### Mirror Service

Use mirrors for migrating between storage services. Uploads go to all services; downloads come from the primary.

```yaml
s3_primary:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: myapp-primary-<%= Rails.env %>

s3_backup:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-west-2
  bucket: myapp-backup-<%= Rails.env %>

production:
  service: Mirror
  primary: s3_primary
  mirrors:
    - s3_backup
```

**Important:** Mirroring is not atomic. An upload can succeed on the primary but fail on a mirror. Verify all files are copied before cutting over.

### Public Access

```yaml
public_s3:
  service: S3
  access_key_id: ...
  secret_access_key: ...
  region: us-east-1
  bucket: myapp-public-<%= Rails.env %>
  public: true
```

With `public: true`, URLs are permanent and unsigned. Ensure your bucket is configured for public read access.

## Variant Processing Deep Dive

### Vips vs MiniMagick

| Feature | Vips (default Rails 7+) | MiniMagick |
|---------|------------------------|------------|
| Speed | ~10x faster | Baseline |
| Memory | ~1/10 of MiniMagick | Heavy |
| Syntax | `resize_to_limit: [w, h]` | `resize: "100x100"` |
| Gem | `ruby-vips` | `mini_magick` |
| System dep | libvips | ImageMagick |

**Set the processor:**
```ruby
# config/application.rb
config.active_storage.variant_processor = :vips  # default in Rails 7+
```

### All Vips Variant Transforms

```ruby
# Resize — preserves aspect ratio, never enlarges
resize_to_limit: [400, 300]

# Resize — fills exact dimensions, crops excess from center
resize_to_fill: [400, 300]

# Resize — fits within bounds, result may be smaller
resize_to_fit: [400, 300]

# Resize — fits within bounds, pads remaining space
resize_and_pad: [400, 300]
resize_and_pad: [400, 300, background: [255, 255, 255]]  # white padding

# Format conversion
format: :webp
format: :png
format: :jpeg

# Quality (JPEG/WebP)
saver: { quality: 80 }

# Rotation
rotate: 90
rotate: 180

# Combine multiple transforms
variant(resize_to_limit: [800, 800], format: :webp, saver: { quality: 85 })
```

### MiniMagick Syntax (legacy)

```ruby
# Only use if variant_processor is :mini_magick
resize: "100x100"
resize: "100x100>"   # Only shrink
resize: "100x100^"   # Fill
crop: "100x100+0+0"
gravity: "Center"
quality: "80"
format: "webp"
```

### Named Variants (Best Practice)

Define variants on the model, not in views:

```ruby
class Product < ApplicationRecord
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_fill: [150, 150], format: :webp, saver: { quality: 80 }
    attachable.variant :card, resize_to_limit: [400, 300], format: :webp, saver: { quality: 85 }
    attachable.variant :hero, resize_to_limit: [1200, 800], format: :webp, saver: { quality: 90 }
  end
end
```

**Use in views:**
```erb
<%= image_tag product.photos.first.variant(:thumb) if product.photos.attached? %>
```

### Preprocessed Variants

Generate variants immediately after upload (in a background job) instead of lazily on first request:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100], preprocessed: true
  end
end
```

This enqueues a job after attachment to generate the variant right away. Useful for avatars, thumbnails — anything that will definitely be displayed.

## Previews (Non-Image Files)

Active Storage can generate image previews for:
- **Videos** — extracts first frame (requires ffmpeg)
- **PDFs** — renders first page (requires poppler or muPDF)

```erb
<%# Video preview %>
<%= image_tag message.video.preview(resize_to_limit: [300, 300]) if message.video.attached? %>

<%# PDF preview %>
<%= image_tag message.document.preview(resize_to_limit: [300, 300]) if message.document.attached? %>
```

**Check if a file is previewable:**
```ruby
message.document.previewable?   # => true for video/PDF
message.document.representable? # => true for images AND previewable files
```

**Use `representation` for universal handling:**
```erb
<% if file.representable? %>
  <%= image_tag file.representation(resize_to_limit: [100, 100]) %>
<% else %>
  <%= link_to "Download", rails_blob_path(file, disposition: "attachment") %>
<% end %>
```

## Direct Uploads

Direct uploads send files from the browser directly to the cloud storage service, bypassing your Rails server.

### Setup

**1. Include Active Storage JavaScript:**

```ruby
# config/importmap.rb
pin "@rails/activestorage", to: "activestorage.esm.js"
```

```js
// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

Or via asset pipeline:
```js
//= require activestorage
```

Or via npm:
```bash
npm install @rails/activestorage
```

**2. Add `direct_upload: true` to file fields:**

```erb
<%= form.file_field :avatar, direct_upload: true %>
<%= form.file_field :images, multiple: true, direct_upload: true %>
```

**3. Configure CORS on cloud storage (required for S3/GCS):**

S3 CORS example:
```json
[
  {
    "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "AllowedMethods": ["PUT"],
    "AllowedOrigins": ["https://www.example.com"],
    "MaxAgeSeconds": 3600
  }
]
```

GCS CORS example:
```json
[
  {
    "origin": ["https://www.example.com"],
    "method": ["PUT"],
    "responseHeader": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "maxAgeSeconds": 3600
  }
]
```

**No CORS needed for Disk service** (same origin).

### JavaScript Events

```js
addEventListener("direct-upload:initialize", event => {
  const { id, file } = event.detail
  // Show upload UI
})

addEventListener("direct-upload:progress", event => {
  const { id, file, progress } = event.detail
  // Update progress bar: progress is 0-100
})

addEventListener("direct-upload:error", event => {
  event.preventDefault()  // Prevent default alert
  const { id, error } = event.detail
  // Show custom error
})

addEventListener("direct-upload:end", event => {
  const { id } = event.detail
  // Mark complete
})
```

### Custom Upload with DirectUpload Class

```js
import { DirectUpload } from "@rails/activestorage"

const upload = new DirectUpload(file, directUploadUrl)

upload.create((error, blob) => {
  if (error) {
    console.error(error)
  } else {
    // blob.signed_id — use as hidden field value
    const hiddenField = document.createElement("input")
    hiddenField.type = "hidden"
    hiddenField.name = "user[avatar]"
    hiddenField.value = blob.signed_id
    form.appendChild(hiddenField)
  }
})
```

## Querying Attachments

Active Storage creates real Active Record associations you can query:

```ruby
# has_one_attached :avatar creates:
#   has_one :avatar_attachment
#   has_one :avatar_blob (through avatar_attachment)

# has_many_attached :images creates:
#   has_many :images_attachments
#   has_many :images_blobs (through images_attachments)

# Find users with PNG avatars
User.joins(:avatar_blob).where(active_storage_blobs: { content_type: "image/png" })

# Find messages with video attachments
Message.joins(:images_blobs).where(active_storage_blobs: { content_type: "video/mp4" })

# Find users with any avatar
User.joins(:avatar_attachment)

# Find users without an avatar
User.left_joins(:avatar_attachment).where(active_storage_attachments: { id: nil })
```

## Serving Files

### Redirect Mode (Default)

```ruby
url_for(user.avatar)
# => /rails/active_storage/blobs/redirect/:signed_id/filename.ext
# Browser gets 302 redirect to the actual storage URL (S3, etc.)

rails_blob_path(user.avatar, disposition: "attachment")  # Force download
```

### Proxy Mode

Files are streamed through your Rails server. Required for CDN support.

```ruby
# Enable globally
# config/initializers/active_storage.rb
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

# Or use per-attachment
rails_storage_proxy_path(user.avatar)
```

### CDN Integration

```ruby
# config/routes.rb
direct :cdn_image do |model, options|
  expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

  if model.respond_to?(:signed_id)
    route_for(
      :rails_service_blob_proxy,
      model.signed_id(expires_in: expires_in),
      model.filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  else
    signed_blob_id = model.blob.signed_id(expires_in: expires_in)
    variation_key  = model.variation.key
    filename       = model.blob.filename

    route_for(
      :rails_blob_representation_proxy,
      signed_blob_id,
      variation_key,
      filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  end
end
```

```erb
<%= cdn_image_url(user.avatar.variant(:thumb)) %>
```

### Authenticated Controllers

Default Active Storage routes are public (hard-to-guess signed URLs, but permanent). For private files:

```ruby
# config/application.rb
config.active_storage.draw_routes = false

# config/routes.rb
resource :account do
  resource :logo
end

# app/controllers/logos_controller.rb
class LogosController < ApplicationController
  before_action :authenticate_user!

  def show
    redirect_to Current.account.logo.url
  end
end
```

## Attaching File/IO Objects

```ruby
# From a file path
record.avatar.attach(
  io: File.open("/path/to/file.jpg"),
  filename: "avatar.jpg",
  content_type: "image/jpeg"
)

# From a string
record.document.attach(
  io: StringIO.new("CSV content here"),
  filename: "report.csv",
  content_type: "text/csv"
)

# From downloaded content
require "open-uri"
record.avatar.attach(
  io: URI.open("https://example.com/photo.jpg"),
  filename: "photo.jpg"
)

# With custom S3 key (folder organization)
record.document.attach(
  io: File.open("/path/to/file.pdf"),
  filename: "report.pdf",
  content_type: "application/pdf",
  key: "#{Rails.env}/reports/#{SecureRandom.uuid}.pdf"
)

# Skip content type detection
record.document.attach(
  io: File.open("/path/to/file"),
  filename: "data.bin",
  content_type: "application/octet-stream",
  identify: false
)
```

## Downloading Files

```ruby
# Into memory (careful with large files)
binary = record.avatar.download

# To a tempfile (preferred for processing)
record.video.open do |tempfile|
  system("/usr/bin/ffprobe", tempfile.path)
end
```

**Important:** Files are not available in `after_create` callbacks. Use `after_create_commit`.

## Purging Unattached Uploads

Direct uploads can create orphaned blobs. Clean them up:

```ruby
# lib/tasks/active_storage.rake
namespace :active_storage do
  desc "Purge unattached blobs older than 2 days"
  task purge_unattached: :environment do
    ActiveStorage::Blob.unattached.where(created_at: ..2.days.ago).find_each(&:purge_later)
  end
end
```

**Warning:** `ActiveStorage::Blob.unattached` can be slow on large databases.

## Analyzers

Active Storage automatically analyzes uploaded files via Active Job:

- **Images:** extracts `width`, `height`
- **Videos:** extracts `width`, `height`, `duration`, `angle`, `display_aspect_ratio`, `video`, `audio`
- **Audio:** extracts `duration`, `bit_rate`

```ruby
blob = record.avatar.blob
blob.analyzed?           # => true (after analysis job runs)
blob.metadata            # => {"identified"=>true, "width"=>800, "height"=>600, "analyzed"=>true}
blob.metadata[:width]    # => 800
blob.metadata[:height]   # => 600
```

## Testing Patterns

### Integration/Request Test with File Upload

```ruby
require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "creates user with avatar" do
    assert_difference "User.count", 1 do
      post users_path, params: {
        user: {
          name: "Test User",
          avatar: file_fixture_upload("test-avatar.png", "image/png")
        }
      }
    end

    user = User.last
    assert user.avatar.attached?
    assert_equal "test-avatar.png", user.avatar.filename.to_s
  end

  test "updates avatar" do
    user = users(:with_avatar)
    patch user_path(user), params: {
      user: { avatar: file_fixture_upload("new-avatar.jpg", "image/jpeg") }
    }

    assert_equal "new-avatar.jpg", user.reload.avatar.filename.to_s
  end
end
```

### Model Test

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "avatar is attached" do
    user = users(:with_avatar)
    assert user.avatar.attached?
  end

  test "avatar is optional" do
    user = User.new(name: "Test", email: "test@example.com")
    assert user.valid?
    refute user.avatar.attached?
  end
end
```

### Fixture-Based Attachments

**1. Create a fixture storage service:**

```yaml
# config/storage.yml
test_fixtures:
  service: Disk
  root: <%= Rails.root.join("tmp/storage_fixtures") %>
```

**2. Create Active Storage fixture files:**

```yaml
# test/fixtures/active_storage/attachments.yml
user_avatar:
  name: avatar
  record: with_avatar (User)
  blob: user_avatar_blob
```

```yaml
# test/fixtures/active_storage/blobs.yml
user_avatar_blob: <%= ActiveStorage::FixtureSet.blob(
  filename: "avatar.png",
  service_name: "test_fixtures"
) %>
```

**3. Place the actual file at `test/fixtures/files/avatar.png`.**

**4. Clean up fixture files:**

```ruby
# test/test_helper.rb
Minitest.after_run do
  FileUtils.rm_rf(ActiveStorage::Blob.services.fetch(:test_fixtures).root)
end

# Or for parallel tests:
class ActiveSupport::TestCase
  parallelize_teardown do |i|
    FileUtils.rm_rf(ActiveStorage::Blob.services.fetch(:test_fixtures).root)
  end
end
```

### System Test Cleanup

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  def after_teardown
    super
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
  end

  # For parallel tests
  parallelize_setup do |i|
    ActiveStorage::Blob.service.root = "#{ActiveStorage::Blob.service.root}-#{i}"
  end
end
```

### Testing with Service-Specific Attachments

If a model uses `has_one_attached :avatar, service: :s3`, create a test override:

```yaml
# config/storage/test.yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

s3:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>
```

This redirects S3 to disk during tests without changing model code.

### Inline Job Processing for Tests

For tests that depend on purge or analysis completing:

```ruby
# config/environments/test.rb
config.active_job.queue_adapter = :inline
```

## Content Type Validation

Active Storage doesn't include built-in validations. Use a gem or roll your own:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar

  validate :acceptable_avatar

  private

  def acceptable_avatar
    return unless avatar.attached?

    unless avatar.blob.content_type.in?(%w[image/png image/jpeg image/gif image/webp])
      errors.add(:avatar, "must be a PNG, JPEG, GIF, or WebP image")
    end

    if avatar.blob.byte_size > 10.megabytes
      errors.add(:avatar, "must be less than 10MB")
    end
  end
end
```

Or use the `active_storage_validations` gem:

```ruby
gem "active_storage_validations"

class User < ApplicationRecord
  has_one_attached :avatar

  validates :avatar, content_type: %w[image/png image/jpeg image/webp],
                     size: { less_than: 10.megabytes }
end
```

## Custom Metadata

Store additional metadata on blobs:

```ruby
blob = record.avatar.blob
blob.update!(metadata: blob.metadata.merge("source" => "api", "original_name" => "photo.jpg"))
```

## Edge Cases & Gotchas

### Polymorphic Type Column
When renaming a model class that uses `has_one_attached` or `has_many_attached`, you must also update the `record_type` column in `active_storage_attachments`. Otherwise, existing attachments become orphaned.

```ruby
class RenameCompanyToOrganization < ActiveRecord::Migration[7.1]
  def up
    rename_table :companies, :organizations
    ActiveStorage::Attachment.where(record_type: "Company").update_all(record_type: "Organization")
  end
end
```

### UUID Primary Keys
If your models use UUIDs, configure the generator before running the Active Storage install:

```ruby
# config/application.rb
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

### File Not Available in after_create
Attached files are only available after the transaction commits. Use `after_create_commit`:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  after_create_commit :process_avatar

  private

  def process_avatar
    return unless avatar.attached?
    # Now the file is available
    avatar.open do |file|
      # process...
    end
  end
end
```

### has_many_attached Replaces by Default
Calling `attach` on `has_many_attached` in Rails replaces all existing attachments. To append:

```ruby
# This REPLACES all existing images
message.images.attach(new_file)

# To KEEP existing and add new, include signed_ids in form (see SKILL.md Step 7)
```

### Variant Lazy Loading
Variants are generated on first request by default. The first user to hit a variant URL waits for processing. Consider using `preprocessed: true` for commonly-accessed variants, or call `.processed` to generate eagerly in a background job.

### Large File Downloads
`blob.download` loads the entire file into memory. For large files, always use `blob.open` which streams to a tempfile:

```ruby
# BAD for large files
data = record.video.download  # Loads entire video into RAM

# GOOD
record.video.open do |tempfile|
  # Process the tempfile
end
```
