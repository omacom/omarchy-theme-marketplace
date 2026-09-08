# Editors — Installation, Lexxy, Trix, Models, and Forms

## Installation Details

### What `action_text:install` Does

1. **Creates migrations** for:
   - `action_text_rich_texts` (polymorphic join table)
   - `active_storage_blobs` (if Active Storage not installed)
   - `active_storage_attachments` (if Active Storage not installed)
   - `active_storage_variant_records` (if Active Storage not installed)

2. **Adds JavaScript** imports to `app/javascript/application.js`:
   ```js
   import "trix"
   import "@rails/actiontext"
   ```

3. **Creates view partials**:
   - `app/views/layouts/action_text/contents/_content.html.erb`
   - `app/views/active_storage/blobs/_blob.html.erb`

4. **Creates stylesheet**: `app/assets/stylesheets/actiontext.css`

5. **Adds `image_processing` gem** to Gemfile

### Schema: `action_text_rich_texts`

```ruby
create_table :action_text_rich_texts do |t|
  t.string     :name, null: false        # The attribute name (e.g., "content")
  t.text       :body                     # The HTML content
  t.references :record, null: false, polymorphic: true, index: false
  t.timestamps

  t.index [:record_type, :record_id, :name], name: "index_action_text_rich_texts_uniqueness", unique: true
end
```

### Active Storage Dependencies

Action Text uses Active Storage for file uploads. Ensure these are available:

| Dependency | Purpose | Install |
|-----------|---------|---------|
| `libvips` | Image analysis & transforms | `apt install libvips` / `brew install vips` |
| `image_processing` gem | Ruby bindings for vips/imagemagick | In Gemfile |
| `ffmpeg` | Video previews (optional) | `apt install ffmpeg` |
| `poppler` | PDF previews (optional) | `apt install poppler-utils` |

---

## Lexxy Editor Configuration

Lexxy is the modern replacement for Trix, shipping with Rails 8.1+.

### Setup

```ruby
# Gemfile
gem "lexxy"
```

```erb
<%# Layout: load lexxy stylesheet BEFORE app styles %>
<%= stylesheet_link_tag "lexxy", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

### Content Wrapper

Update the Action Text content partial to use Lexxy's class:

```erb
<%# app/views/layouts/action_text/contents/_content.html.erb %>
<div class="lexxy-content">
  <%= yield %>
</div>
```

### Full CSS Variables Reference

Override these in your app CSS (loaded after `lexxy.css`):

```css
:root {
  /* Ink (text) colors */
  --lexxy-color-ink: /* Primary text */;
  --lexxy-color-ink-medium: /* Secondary text */;
  --lexxy-color-ink-light: /* Tertiary/subtle text */;
  --lexxy-color-ink-lighter: /* Borders, dividers */;
  --lexxy-color-ink-lightest: /* Subtle backgrounds */;
  --lexxy-color-ink-inverted: /* Inverted text (on dark bg) */;

  /* Canvas and text */
  --lexxy-color-canvas: /* Editor background */;
  --lexxy-color-text: /* Editor text */;
  --lexxy-color-text-subtle: /* Placeholder text */;
  --lexxy-color-link: /* Link color */;
  --lexxy-color-code-bg: /* Code block background */;

  /* Selection */
  --lexxy-color-selected: /* Selection background */;
  --lexxy-color-selected-hover: /* Selection hover */;

  /* Accents */
  --lexxy-color-accent-dark: /* Primary accent */;
  --lexxy-color-accent-medium: /* Secondary accent */;
  --lexxy-color-accent-light: /* Light accent */;
  --lexxy-color-accent-lightest: /* Lightest accent */;

  /* Focus */
  --lexxy-focus-ring-color: /* Focus outline color */;

  /* Typography */
  --lexxy-font-base: /* Base font family */;
  --lexxy-font-mono: /* Monospace font family */;
}
```

### Dark Mode Pattern

```css
:root {
  color-scheme: light dark;

  --lexxy-color-canvas: light-dark(#ffffff, #1a1a1a);
  --lexxy-color-text: light-dark(#1a1a1a, #e5e5e5);
  --lexxy-color-link: light-dark(#2563eb, #60a5fa);
  --lexxy-color-code-bg: light-dark(#f5f5f5, #2a2a2a);
  --lexxy-color-selected: light-dark(oklch(0.92 0.026 254), oklch(0.3 0.05 254));
}
```

### Editor Sizing

```css
lexxy-editor,
.lexxy-editor {
  min-height: 200px;  /* Minimum editor height */
  max-height: 600px;  /* Optional: cap height */
  overflow-y: auto;   /* Scroll when exceeding max */
}
```

---

## Trix Editor Configuration

Trix is the original Action Text editor. Still the default in Rails 6–8.0.

### Toolbar Customization

```js
// Disable file attachments
document.addEventListener("trix-file-accept", (event) => {
  event.preventDefault()
  alert("File attachments are not supported")
})

// Custom toolbar actions
document.addEventListener("trix-initialize", (event) => {
  const toolbar = event.target.toolbarElement
  // Modify toolbar HTML as needed
})
```

### Disable Specific Toolbar Buttons

```css
/* Hide the file attachment button */
trix-toolbar .trix-button--icon-attach { display: none; }

/* Hide code formatting */
trix-toolbar .trix-button--icon-code { display: none; }

/* Hide heading button */
trix-toolbar .trix-button--icon-heading-1 { display: none; }
```

---

## Model Patterns

### Single Rich Text Field

```ruby
class Article < ApplicationRecord
  has_rich_text :content
end
```

### Multiple Rich Text Fields

```ruby
class Product < ApplicationRecord
  has_rich_text :description
  has_rich_text :specifications
  has_rich_text :care_instructions
end
```

### Rich Text with Validations

Action Text doesn't ship with built-in validations. Add custom ones:

```ruby
class Article < ApplicationRecord
  has_rich_text :content

  validate :content_not_blank
  validate :content_length

  private

  def content_not_blank
    errors.add(:content, "can't be blank") if content.blank?
  end

  def content_length
    if content.to_plain_text.length > 10_000
      errors.add(:content, "is too long (maximum 10,000 characters)")
    end
  end
end
```

### Rich Text with Callbacks

```ruby
class Article < ApplicationRecord
  has_rich_text :content

  before_save :extract_plain_text_excerpt

  private

  def extract_plain_text_excerpt
    self.excerpt = content.to_plain_text.truncate(300) if content.present?
  end
end
```

### Checking for Attachments

```ruby
article = Article.find(1)

# Check if content has any attachments
article.content.embeds.any?

# Count attachments
article.content.embeds.count

# Access attachment blobs
article.content.embeds.map(&:blob)
```

---

## Form Patterns

### Basic Form

```erb
<%= form_with model: @article do |form| %>
  <%= form.rich_text_area :content %>
<% end %>
```

### With Placeholder

```erb
<%= form.rich_text_area :content, placeholder: "Write your article..." %>
```

### With Stimulus Controller

```erb
<%= form.rich_text_area :content,
      data: { controller: "autosave", autosave_url_value: autosave_article_path(@article) } %>
```

### Multiple Rich Text Fields in One Form

```erb
<%= form_with model: @product do |form| %>
  <div class="field">
    <%= form.label :description, "Product Description" %>
    <%= form.rich_text_area :description %>
  </div>

  <div class="field">
    <%= form.label :specifications, "Technical Specs" %>
    <%= form.rich_text_area :specifications %>
  </div>
<% end %>
```

### Controller Params

```ruby
class ProductsController < ApplicationController
  private

  def product_params
    params.expect(product: [:name, :price, :description, :specifications])
  end
end
```
