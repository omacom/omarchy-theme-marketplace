# Attachments, Custom Attachables, and API Usage

## Attachment Patterns

### Image Attachments

Images dragged into the editor are automatically uploaded via Active Storage Direct Upload.

**Customize the blob partial:**

```erb
<%# app/views/active_storage/blobs/_blob.html.erb %>
<figure class="attachment attachment--<%= blob.representable? ? "preview" : "file" %> attachment--<%= blob.filename.extension %>">
  <% if blob.representable? %>
    <%= image_tag blob.representation(resize_to_limit: local_assigns[:in_gallery] ? [800, 600] : [1024, 768]),
          loading: "lazy",
          class: "attachment__image" %>
  <% end %>

  <figcaption class="attachment__caption">
    <% if caption = blob.try(:caption) %>
      <%= caption %>
    <% else %>
      <span class="attachment__name"><%= blob.filename %></span>
      <span class="attachment__size"><%= number_to_human_size blob.byte_size %></span>
    <% end %>
  </figcaption>
</figure>
```

### Disable File Attachments

If you don't want file uploads in the editor:

```js
// Trix
document.addEventListener("trix-file-accept", (event) => {
  event.preventDefault()
})
```

### Restrict File Types

```js
// Trix: Only allow images
document.addEventListener("trix-file-accept", (event) => {
  const acceptedTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"]
  if (!acceptedTypes.includes(event.file.type)) {
    event.preventDefault()
    alert("Only image files are allowed")
  }
})
```

### Restrict File Size

```js
// Trix: Max 10MB
document.addEventListener("trix-file-accept", (event) => {
  const maxSize = 10 * 1024 * 1024 // 10MB
  if (event.file.size > maxSize) {
    event.preventDefault()
    alert("File is too large (max 10MB)")
  }
})
```

### Direct Upload Progress

```js
addEventListener("direct-upload:progress", (event) => {
  const { id, progress } = event.detail
  const progressBar = document.getElementById(`direct-upload-${id}`)
  if (progressBar) progressBar.style.width = `${progress}%`
})
```

### Purging Unattached Uploads

Files uploaded but never saved in rich text content become orphaned. Clean them up:

```ruby
# In a recurring job
ActiveStorage::Blob.unattached.where("created_at < ?", 2.days.ago).find_each(&:purge_later)
```

---

## Custom Attachables

Embed any model inside rich text content using Signed GlobalIDs.

### Basic Custom Attachable

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include ActionText::Attachable

  # Custom partial for rendering inside rich text
  def to_attachable_partial_path
    "users/mention"
  end
end
```

```erb
<%# app/views/users/_mention.html.erb %>
<span class="user-mention" data-user-id="<%= user.id %>">
  <%= image_tag user.avatar_url, class: "user-mention__avatar", size: "20x20" if user.avatar_url %>
  @<%= user.name %>
</span>
```

### Inserting Attachables Programmatically

```ruby
user = User.find(1)
sgid = user.attachable_sgid

# Build the attachment HTML
attachment_html = %(<action-text-attachment sgid="#{sgid}"></action-text-attachment>)

# Use in content
article.update!(content: "Hello #{attachment_html}, welcome!")
```

### Product Embed Example

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  include ActionText::Attachable

  def to_attachable_partial_path
    "products/embed"
  end

  def self.to_missing_attachable_partial_path
    "products/missing_embed"
  end
end
```

```erb
<%# app/views/products/_embed.html.erb %>
<div class="product-embed">
  <% if product.image.attached? %>
    <%= image_tag product.image.variant(resize_to_fill: [80, 80]), class: "product-embed__image" %>
  <% end %>
  <div class="product-embed__info">
    <strong><%= product.name %></strong>
    <span class="product-embed__price"><%= number_to_currency product.price %></span>
  </div>
</div>
```

```erb
<%# app/views/products/missing_embed.html.erb %>
<div class="product-embed product-embed--missing">
  <span>Product no longer available</span>
</div>
```

### Custom SGIDs with Expiration

```ruby
user.attachable_sgid                              # Default: no expiration
user.to_sgid(expires_in: 1.hour).to_s             # Expires in 1 hour
user.to_sgid(for: "action_text_attachable").to_s   # Scoped purpose
```

---

## API / Headless Usage

### Creating Rich Text via API

```ruby
# In an API controller
class Api::ArticlesController < ApiController
  def create
    article = Article.create!(
      title: params[:title],
      content: params[:content]  # Accepts HTML string
    )
    render json: { id: article.id, content_html: article.content.to_s }
  end
end
```

### Attachment Upload Endpoint

```ruby
# For frontend apps that need to upload files separately
class Api::AttachmentsController < ApiController
  def create
    blob = ActiveStorage::Blob.create_and_upload!(
      io: params[:file],
      filename: params[:file].original_filename,
      content_type: params[:file].content_type
    )
    render json: {
      attachable_sgid: blob.attachable_sgid,
      url: url_for(blob)
    }
  end
end
```

### Embedding Uploaded Attachments

```html
<!-- Frontend inserts this into the rich text HTML -->
<action-text-attachment sgid="BAh7CEkiCG..."></action-text-attachment>
```
