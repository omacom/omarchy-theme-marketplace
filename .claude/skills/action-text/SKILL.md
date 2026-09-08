---
name: action-text
description: Expert guidance for implementing rich text editing with Action Text in Rails. Use when adding rich text fields, configuring Lexxy or Trix editors, rendering rich text content, handling attachments and embeds, creating custom attachables, styling rich text, or fixing N+1 queries with rich text. Triggers on "action text", "rich text", "lexxy", "trix", "WYSIWYG", "rich text editor", "has_rich_text", "text editor", "rich content", "embedded content", "rich_text_area", "action-text-attachment".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails action_text:*), Bash(bin/rails db:migrate), Bash(bin/rails generate*), Bash(bundle *)
---

# Rails Action Text Expert

Implement rich text editing in Rails applications using Action Text with the Lexxy editor (Rails 8.1+) or Trix (Rails 6-8.0).

## Key Concepts

Action Text stores rich text in a separate `action_text_rich_texts` table via polymorphic associations — **not** in your model's table. It handles sanitization, rendering, attachments (via Active Storage), and embedded objects (via Signed GlobalIDs).

**Editor History:**
- **Trix** — Original Action Text editor (Rails 6+). Still works, still supported.
- **Lexxy** — Modern replacement from Basecamp (Rails 8.1+). Better dark mode, CSS custom properties, improved UX. **Use Lexxy for new projects.**

## When To Use This Skill

- Adding rich text fields to a model
- Setting up Action Text in a new or existing Rails app
- Configuring Lexxy or Trix editor appearance
- Rendering rich text content safely
- Handling image/file attachments in rich text
- Creating custom attachable objects (embed users, products, etc.)
- Fixing N+1 queries with rich text
- Styling the editor and rendered content
- Testing rich text functionality

## Instructions

### Step 1: Check If Action Text Is Installed

```bash
# Check for Action Text tables
bin/rails runner "puts ActiveRecord::Base.connection.table_exists?('action_text_rich_texts')"

# Check for Action Text config files
ls app/views/layouts/action_text/contents/_content.html.erb 2>/dev/null
ls app/views/active_storage/blobs/_blob.html.erb 2>/dev/null

# Check Gemfile for editor
grep -E "trix|lexxy" Gemfile
```

If not installed, run installation first (Step 2). If already installed, skip to Step 3.

### Step 2: Install Action Text

```bash
bin/rails action_text:install
bin/rails db:migrate
```

**This creates:**
- Migration for `action_text_rich_texts` table (+ Active Storage tables if missing)
- JavaScript imports for the editor
- `app/views/layouts/action_text/contents/_content.html.erb` — content wrapper partial
- `app/views/active_storage/blobs/_blob.html.erb` — attachment rendering partial
- `app/assets/stylesheets/actiontext.css` — default styles

**For Lexxy (Rails 8.1+), also add:**

```ruby
# Gemfile
gem "lexxy"
```

```bash
bundle install
```

**Critical: Stylesheet load order for Lexxy:**

```erb
<%# app/views/layouts/application.html.erb %>
<%# Lexxy FIRST, then app styles (so your overrides win) %>
<%= stylesheet_link_tag "lexxy", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

**Common Agent Mistake:** Forgetting `bin/rails action_text:install`. Without it, the migration, JS imports, and view partials are missing. The `has_rich_text` declaration alone is not enough.

### Step 3: Add Rich Text to a Model

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  has_rich_text :content
end
```

**Key facts:**
- No column needed on the `articles` table — content lives in `action_text_rich_texts`
- The attribute name is arbitrary (`:content`, `:body`, `:description`, etc.)
- A model can have multiple rich text attributes: `has_rich_text :body` and `has_rich_text :summary`
- Each `has_rich_text` creates a separate `ActionText::RichText` record

### Step 4: Add the Editor to Forms

```erb
<%# app/views/articles/_form.html.erb %>
<%= form_with model: @article do |form| %>
  <div class="field">
    <%= form.label :content %>
    <%= form.rich_text_area :content %>
  </div>
<% end %>
```

**Permit the attribute in the controller:**

```ruby
class ArticlesController < ApplicationController
  def create
    @article = Article.create!(article_params)
    redirect_to @article
  end

  private

  def article_params
    params.expect(article: [:title, :content])
  end
end
```

**Note:** `rich_text_area` (or `rich_textarea`) — both work. The rich text content is a single string param; no special nesting required.

### Step 5: Render Rich Text Content

```erb
<%# Safe — Action Text sanitizes content automatically %>
<%= @article.content %>
```

That's it. `ActionText::RichText#to_s` returns sanitized HTML safe for direct embedding.

**For plain text (e.g., excerpts, meta descriptions):**

```ruby
@article.content.to_plain_text
# => "Hello world. This is bold text."

# Truncated excerpt
truncate(@article.content.to_plain_text, length: 150)
```

**Check for content presence:**

```ruby
@article.content.blank?  # true if no content
@article.content.present? # true if has content
```

### Step 6: Style the Editor and Content

#### Lexxy (Rails 8.1+)

**Editor sizing:**

```css
lexxy-editor,
.lexxy-editor {
  min-height: 300px;
}
```

**Rendered content styling (use `.lexxy-content` wrapper):**

```erb
<%# app/views/layouts/action_text/contents/_content.html.erb %>
<div class="lexxy-content">
  <%= yield %>
</div>
```

```css
.lexxy-content {
  line-height: 1.6;
  overflow-wrap: break-word;
}

.lexxy-content p { margin: 0 0 1rem; }
.lexxy-content h1, .lexxy-content h2, .lexxy-content h3 {
  font-weight: 600;
  line-height: 1.3;
  margin: 1.5rem 0 0.75rem;
}
.lexxy-content ul, .lexxy-content ol {
  margin: 0 0 1rem;
  padding-left: 1.5rem;
}
.lexxy-content blockquote {
  border-left: 3px solid var(--color-border);
  margin: 1rem 0;
  padding: 0.5rem 0 0.5rem 1rem;
  color: var(--color-ink-muted);
}
.lexxy-content code {
  font-size: 0.875em;
  background: var(--color-surface-muted);
  padding: 0.125rem 0.375rem;
  border-radius: 4px;
}
.lexxy-content pre {
  background: var(--color-surface-muted);
  border-radius: 8px;
  padding: 1rem;
  overflow-x: auto;
  margin: 1rem 0;
}
```

**Dark mode with CSS custom properties:**

```css
:root {
  --lexxy-color-canvas: var(--color-surface);
  --lexxy-color-text: var(--color-ink);
  --lexxy-color-link: var(--color-link);
  --lexxy-color-code-bg: var(--color-surface-muted);
  --lexxy-focus-ring-color: var(--color-primary);
}
```

See `references/editors.md` for the full list of Lexxy CSS variables.

#### Trix (Rails 6–8.0)

**Content wrapper uses `.trix-content`:**

```erb
<%# app/views/layouts/action_text/contents/_content.html.erb %>
<div class="trix-content">
  <%= yield %>
</div>
```

**Override styles in `app/assets/stylesheets/actiontext.css`.**

**Common Agent Mistake:** Not styling Action Text content at all. The raw output looks unstyled. Always provide CSS for `.trix-content` or `.lexxy-content`.

### Step 7: Handle Attachments

Action Text uses Active Storage for file attachments (images, files dragged/dropped into the editor).

**Prerequisites:**
- Active Storage must be installed (`bin/rails active_storage:install`)
- `libvips` or `ImageMagick` for image processing
- `image_processing` gem in Gemfile

**Customize attachment rendering:**

```erb
<%# app/views/active_storage/blobs/_blob.html.erb %>
<figure class="attachment attachment--<%= blob.representable? ? "preview" : "file" %> attachment--<%= blob.filename.extension %>">
  <% if blob.representable? %>
    <%= image_tag blob.representation(resize_to_limit: local_assigns[:in_gallery] ? [800, 600] : [1024, 768]) %>
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

### Step 8: Avoid N+1 Queries

**This is critical.** Loading rich text triggers extra queries per record. Always preload.

```ruby
# BAD — N+1 queries (one query per article for rich text)
Article.all.each { |a| a.content.to_s }

# GOOD — Preload rich text
Article.all.with_rich_text_content

# GOOD — Preload rich text AND its embedded attachments
Article.all.with_rich_text_content_and_embeds
```

**The scope name is dynamic:** `with_rich_text_#{name}` and `with_rich_text_#{name}_and_embeds` based on your `has_rich_text :name` declaration.

```ruby
# If you have: has_rich_text :body
Article.with_rich_text_body
Article.with_rich_text_body_and_embeds

# If you have: has_rich_text :description
Product.with_rich_text_description_and_embeds
```

**Common Agent Mistake:** Forgetting `_and_embeds`. Without it, attachment images trigger additional queries when rendering.

### Step 9: Custom Attachables (Embeds)

Embed any Active Record model inside rich text using Signed GlobalIDs.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include ActionText::Attachable

  def to_attachable_partial_path
    "users/mention"
  end
end
```

```erb
<%# app/views/users/_mention.html.erb %>
<span class="user-mention">@<%= user.name %></span>
```

**Inserting programmatically:**

```ruby
user = User.find(1)
html = %(<action-text-attachment sgid="#{user.attachable_sgid}"></action-text-attachment>)
article.update!(content: "Hello #{html}")
```

**Handle deleted records gracefully:**

```ruby
class User < ApplicationRecord
  include ActionText::Attachable

  def self.to_missing_attachable_partial_path
    "users/missing_mention"
  end
end
```

```erb
<%# app/views/users/missing_mention.html.erb %>
<span class="user-mention user-mention--deleted">@deleted user</span>
```

### Step 10: Testing Rich Text

**Model tests:**

```ruby
require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "accepts rich text content" do
    article = Article.new(title: "Test", content: "<h1>Hello</h1><p>World</p>")
    assert article.content.present?
    assert_includes article.content.to_plain_text, "Hello"
    assert_includes article.content.to_plain_text, "World"
  end

  test "content is blank when not set" do
    article = Article.new(title: "Test")
    assert article.content.blank?
  end
end
```

**Request tests:**

```ruby
require "test_helper"

class ArticlesRequestTest < ActionDispatch::IntegrationTest
  test "creates article with rich text" do
    assert_difference "Article.count", 1 do
      post articles_path, params: {
        article: { title: "Test", content: "<p>Rich text body</p>" }
      }
    end
    assert_equal "Rich text body", Article.last.content.to_plain_text
  end
end
```

**System tests (for editor interaction):**

```ruby
require "application_system_test_case"

class ArticlesSystemTest < ApplicationSystemTestCase
  test "creates article with rich text editor" do
    visit new_article_path
    fill_in "Title", with: "My Article"

    # Fill the rich text editor
    find("trix-editor").click
    find("trix-editor").set("Hello from the editor")

    click_on "Create Article"
    assert_text "Hello from the editor"
  end
end
```

### UUID Primary Keys

If your models use UUIDs, update the Action Text migration:

```ruby
# In the generated migration
t.references :record, null: false, polymorphic: true, index: false, type: :uuid
```

### Content Security

Action Text sanitizes HTML on render using a safe-list approach. Only allowed tags and attributes pass through. You do **not** need to call `sanitize` manually.

**Custom sanitization (if needed):**

```ruby
# config/application.rb
config.action_text.sanitizer_allowed_tags = ActionText::ContentHelper::ALLOWED_TAGS + ["iframe"]
config.action_text.sanitizer_allowed_attributes = ActionText::ContentHelper::ALLOWED_ATTRIBUTES + ["src", "frameborder"]
```

⚠️ **Be extremely careful expanding the allow-list.** Adding `<iframe>` or `<script>` opens XSS vectors. Only do this if you trust all content authors.

## Quick Reference

### Essential Commands

```bash
bin/rails action_text:install      # Install Action Text
bin/rails db:migrate               # Run migrations
bin/rails active_storage:install   # Install Active Storage (if not present)
```

### Model Declaration

```ruby
has_rich_text :content                    # Single rich text field
has_rich_text :body                       # Name it whatever you want
has_rich_text :content                    # Multiple fields OK
has_rich_text :summary                    #   on the same model
```

### Form Helpers

```erb
<%= form.rich_text_area :content %>
<%= form.rich_text_area :content, placeholder: "Write something..." %>
<%= form.rich_text_area :content, data: { controller: "editor" } %>
```

### Rendering

```erb
<%= @article.content %>                           # Safe HTML
<%= @article.content.to_plain_text %>             # Plain text
<%= truncate(@article.content.to_plain_text, length: 200) %>  # Excerpt
```

### Preloading (Prevent N+1)

```ruby
Model.with_rich_text_fieldname                    # Preload text only
Model.with_rich_text_fieldname_and_embeds         # Preload text + attachments
```

### Key Files

| File | Purpose |
|------|---------|
| `app/views/layouts/action_text/contents/_content.html.erb` | Content wrapper (`.trix-content` or `.lexxy-content`) |
| `app/views/active_storage/blobs/_blob.html.erb` | Attachment rendering template |
| `app/assets/stylesheets/actiontext.css` | Default Action Text styles |

## Anti-Patterns to Avoid

1. **Skipping the install generator** — `has_rich_text` without `action_text:install` = missing tables, JS, and partials
2. **No content styling** — Raw Action Text output needs CSS for `.trix-content`/`.lexxy-content`
3. **Ignoring N+1** — Always use `with_rich_text_X_and_embeds` in list views
4. **Adding a column to the model** — Rich text lives in `action_text_rich_texts`, not your table
5. **Manual HTML sanitization** — Action Text handles this; double-sanitizing breaks content
6. **Wrong stylesheet order with Lexxy** — Lexxy CSS must load before your app CSS
7. **Missing Active Storage dependencies** — No `libvips` = broken image rendering
8. **Not handling missing attachables** — Deleted records render as empty boxes without `to_missing_attachable_partial_path`
