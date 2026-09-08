# XSS Deep Dive

## How Rails Auto-Escaping Works

ERB's `<%= %>` calls `html_escape` on the output unless the string is already marked `html_safe`. This is why `<%= user.name %>` is safe — it escapes `<`, `>`, `&`, `"`, `'`.

## The html_safe Trap

Calling `.html_safe` marks a string as "already escaped" — Rails will NOT escape it again. This is the #1 way agents introduce XSS:

```ruby
# String marked html_safe is NEVER escaped again
"<script>alert('XSS')</script>".html_safe
# => Rendered as literal script tag. XSS!

# Concatenation with + preserves html_safe status of the LEFT operand
safe = "<b>Bold</b>".html_safe
unsafe = params[:name]
result = safe + unsafe  # unsafe part IS escaped — safe
result = unsafe + safe  # NEITHER is escaped — XSS if unsafe has HTML
```

## Safe Patterns for Building HTML in Helpers

```ruby
# BEST: Use tag helpers
def status_badge(status)
  tag.span(status, class: "badge badge-#{status}")
end

# GOOD: Use content_tag
def icon_link(text, url)
  content_tag(:a, href: url) do
    content_tag(:i, "", class: "icon") + " " + text
  end
end

# ACCEPTABLE: Manual escaping with string building
def labeled_value(label, value)
  "<dt>#{ERB::Util.html_escape(label)}</dt><dd>#{ERB::Util.html_escape(value)}</dd>".html_safe
end

# WRONG: Interpolating user data into html_safe string
def labeled_value(label, value)
  "<dt>#{label}</dt><dd>#{value}</dd>".html_safe  # XSS!
end
```

## sanitize() In Depth

```ruby
# Default allowed tags/attributes — check ActionView::Helpers::SanitizeHelper
sanitize(user_html)

# Explicit allowlist — always preferred
sanitize(user_html,
  tags: %w[p br strong em a ul ol li h2 h3 blockquote code pre],
  attributes: %w[href title class]
)

# Strip ALL HTML
strip_tags(user_html)

# Strip links only
strip_links(user_html)
```

## Action Text

Action Text sanitizes rich text content automatically through its own sanitizer. If you use Action Text for user-generated rich content, you get XSS protection for free — but review the allowed tags if you customize.

## XSS in JavaScript Context

Auto-escaping only protects HTML context. Data injected into JavaScript needs different handling:

```erb
<!-- WRONG — XSS in JS context -->
<script>
  var name = "<%= @user.name %>";  // Escapes HTML, not JS
</script>

<!-- CORRECT — use json_escape or to_json -->
<script>
  var name = <%= @user.name.to_json %>;
  var data = <%= json_escape(@data.to_json) %>;
</script>

<!-- BEST — use data attributes -->
<div data-name="<%= @user.name %>" data-config="<%= @config.to_json %>">
</div>
```

## Content-Type Matters

```ruby
# Rendering user content as HTML is dangerous
render html: user_input  # XSS if not escaped

# Rendering as plain text is safe
render plain: user_input

# JSON responses auto-escape HTML entities
render json: { name: user_input }  # Safe — JSON-encoded
```
