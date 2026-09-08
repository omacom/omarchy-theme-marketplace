# File Upload Security

## Active Storage Validations

```ruby
class User < ApplicationRecord
  has_one_attached :avatar

  validates :avatar,
    content_type: ["image/png", "image/jpeg", "image/webp"],
    size: { less_than: 5.megabytes }
end

class Document < ApplicationRecord
  has_one_attached :file

  validates :file,
    content_type: {
      in: ["application/pdf", "text/plain"],
      message: "must be a PDF or text file"
    },
    size: { less_than: 25.megabytes }
end
```

## Serving User Uploads Safely

```ruby
# Active Storage default: redirect mode (safe — serves from storage service URL)
config.active_storage.resolve_model_to_route = :rails_storage_redirect

# AVOID proxy mode for user uploads on your main domain
# It serves files through your app — potential for stored XSS with HTML files
config.active_storage.resolve_model_to_route = :rails_storage_proxy

# BEST: Serve from a different domain/CDN to isolate cookies
# Configure your storage service to serve from a separate origin
```

## Filename Sanitization

Active Storage handles filename sanitization, but if you're doing manual file handling:

```ruby
# Active Storage does this internally
ActiveStorage::Filename.new(user_provided_name).sanitized

# Manual sanitization
def sanitize_filename(name)
  name.strip.gsub(/[^\w.\-]/, "_").gsub(/\.{2,}/, ".")
end
```

## Path Traversal Prevention

```ruby
# WRONG — path traversal: "../../../etc/passwd"
send_file("/uploads/#{params[:filename]}")

# CORRECT — verify the file is in the expected directory
basename = Rails.root.join("uploads").to_s
filepath = File.expand_path(File.join(basename, params[:filename]))
raise SecurityError unless filepath.start_with?(basename)
send_file(filepath)

# BEST — use database IDs, not filenames
document = Current.user.documents.find(params[:id])
send_file(document.file.path)
```
