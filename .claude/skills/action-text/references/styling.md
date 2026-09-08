# Styling and Rendering Rich Text Content

## Rendering Patterns

### Basic Rendering

```erb
<%# Renders sanitized HTML — safe to embed directly %>
<%= @article.content %>
```

### With Wrapper Class

```erb
<div class="article-body lexxy-content">
  <%= @article.content %>
</div>
```

### Plain Text Extraction

```ruby
# Full plain text (strips all HTML)
@article.content.to_plain_text
# => "Hello world. This is bold text."

# Truncated for previews
@article.content.to_plain_text.truncate(150)

# For meta description
content_tag :meta, nil, name: "description",
  content: @article.content.to_plain_text.truncate(160)
```

### Conditional Rendering

```erb
<% if @article.content.present? %>
  <div class="article-content">
    <%= @article.content %>
  </div>
<% else %>
  <p class="text-muted">No content yet.</p>
<% end %>
```

### Rendering in JSON (API)

```ruby
class ArticleSerializer
  def as_json
    {
      id: article.id,
      title: article.title,
      content_html: article.content.to_s,           # Sanitized HTML
      content_plain: article.content.to_plain_text,  # Plain text
      has_attachments: article.content.embeds.any?
    }
  end
end
```

---

## Styling Reference

### Comprehensive Lexxy Content Styles

```css
.lexxy-content {
  line-height: 1.6;
  overflow-wrap: break-word;
  word-break: break-word;
}

/* Paragraphs */
.lexxy-content p {
  margin: 0 0 1rem;
}

/* Headings */
.lexxy-content h1 {
  font-size: 1.75rem;
  font-weight: 700;
  margin: 2rem 0 0.75rem;
}
.lexxy-content h2 {
  font-size: 1.375rem;
  font-weight: 600;
  margin: 1.75rem 0 0.75rem;
}
.lexxy-content h3 {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 1.5rem 0 0.75rem;
}

/* First child: no top margin */
.lexxy-content > :first-child { margin-top: 0; }

/* Lists */
.lexxy-content ul,
.lexxy-content ol {
  margin: 0 0 1rem;
  padding-left: 1.5rem;
}
.lexxy-content li { margin-bottom: 0.25rem; }
.lexxy-content li > ul,
.lexxy-content li > ol { margin-top: 0.25rem; margin-bottom: 0; }

/* Links */
.lexxy-content a {
  color: var(--lexxy-color-link, #2563eb);
  text-decoration: underline;
  text-underline-offset: 2px;
}
.lexxy-content a:hover { text-decoration-thickness: 2px; }

/* Blockquotes */
.lexxy-content blockquote {
  border-left: 3px solid var(--color-border, #d1d5db);
  margin: 1rem 0;
  padding: 0.5rem 0 0.5rem 1rem;
  color: var(--color-ink-muted, #6b7280);
}

/* Code */
.lexxy-content code {
  font-family: var(--lexxy-font-mono, ui-monospace, monospace);
  font-size: 0.875em;
  background: var(--lexxy-color-code-bg, #f5f5f5);
  padding: 0.125rem 0.375rem;
  border-radius: 4px;
}
.lexxy-content pre {
  background: var(--lexxy-color-code-bg, #f5f5f5);
  border-radius: 8px;
  padding: 1rem;
  margin: 1rem 0;
  overflow-x: auto;
}
.lexxy-content pre code {
  background: none;
  padding: 0;
  border-radius: 0;
}

/* Horizontal rule */
.lexxy-content hr {
  border: none;
  border-top: 1px solid var(--color-border, #e5e7eb);
  margin: 2rem 0;
}

/* Images / attachments */
.lexxy-content .attachment {
  margin: 1rem 0;
  max-width: 100%;
}
.lexxy-content .attachment img {
  max-width: 100%;
  height: auto;
  border-radius: 6px;
}
.lexxy-content .attachment__caption {
  font-size: 0.875rem;
  color: var(--color-ink-muted, #6b7280);
  margin-top: 0.5rem;
  text-align: center;
}
```

### Trix Content Styles

Same patterns apply, but use `.trix-content` instead of `.lexxy-content`:

```css
.trix-content { /* ... same structure ... */ }
```

---

## N+1 Query Prevention

### The Problem

Each `has_rich_text` declaration creates a polymorphic association. Accessing it triggers a query:

```ruby
# Generates N+1 queries
@articles = Article.all
@articles.each do |article|
  article.content.to_s  # Query per article!
end
```

### The Solution

```ruby
# In controller
@articles = Article.with_rich_text_content

# With attachments too
@articles = Article.with_rich_text_content_and_embeds

# Multiple rich text fields
@products = Product
  .with_rich_text_description_and_embeds
  .with_rich_text_specifications
```

### In Scopes

```ruby
class Article < ApplicationRecord
  has_rich_text :content

  scope :for_index, -> {
    with_rich_text_content
    .order(created_at: :desc)
    .limit(20)
  }

  scope :for_feed, -> {
    with_rich_text_content_and_embeds
    .includes(:author)
    .order(published_at: :desc)
  }
end
```

### In Associations

```ruby
class Author < ApplicationRecord
  has_many :articles

  def recent_articles
    articles.with_rich_text_content.order(created_at: :desc).limit(5)
  end
end
```
