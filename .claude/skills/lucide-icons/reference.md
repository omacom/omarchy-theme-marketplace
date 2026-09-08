# Lucide Icons — Reference

Detailed patterns, edge cases, and advanced usage for Lucide icons in Rails.

## Table of Contents

- [Helper Deep Dive](#helper-deep-dive)
- [Layout Patterns](#layout-patterns)
- [Animation](#animation)
- [Conditional Icons](#conditional-icons)
- [Icon Helpers & Wrappers](#icon-helpers--wrappers)
- [Turbo & Stimulus Patterns](#turbo--stimulus-patterns)
- [Flash Messages with Icons](#flash-messages-with-icons)
- [Table Row Actions](#table-row-actions)
- [Dropdown Menus](#dropdown-menus)
- [Form Icons](#form-icons)
- [Loading States](#loading-states)
- [Toggle Icons](#toggle-icons)
- [Responsive Icon Sizing](#responsive-icon-sizing)
- [Troubleshooting](#troubleshooting)
- [Icon Name Gotchas](#icon-name-gotchas)
- [Performance Notes](#performance-notes)

---

## Helper Deep Dive

### All Parameters

```erb
<%= lucide_icon "icon-name",
  size: 18,                          # Width and height (px)
  class: "my-class",                 # CSS classes
  stroke_width: 2,                   # Stroke width (default: 2)
  data: { action: "click->x#y" },   # data-* attributes
  aria: { label: "Description" },    # aria-* attributes
  id: "my-icon",                     # HTML id
  style: "margin-right: 4px"         # Inline styles (prefer classes)
%>
```

### The SVG Output

Every `lucide_icon` call produces:
```html
<svg
  xmlns="http://www.w3.org/2000/svg"
  width="SIZE" height="SIZE"
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="STROKE_WIDTH"
  stroke-linecap="round"
  stroke-linejoin="round"
  class="YOUR_CLASSES"
>
  <!-- icon paths -->
</svg>
```

Key points:
- `viewBox` is always `0 0 24 24` regardless of `size` — icons scale cleanly
- `fill="none"` — these are stroke-based icons, not filled
- `stroke="currentColor"` — inherits from CSS `color` property
- All extra attributes are passed through to the `<svg>` element

---

## Layout Patterns

### Flexbox Alignment (The Standard)

Icons inline with text should use flexbox:

```css
/* Base pattern for anything with icon + text */
.with-icon {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem; /* 8px — adjust per context */
}
```

```erb
<span class="with-icon">
  <%= lucide_icon "check-circle", size: 16 %>
  Saved successfully
</span>
```

### Vertical Alignment Without Flexbox

If you can't use flexbox (e.g., inline in a paragraph):

```css
svg {
  vertical-align: middle; /* or -0.125em for precise baseline alignment */
}
```

### Icon Left vs Icon Right

```erb
<%# Icon left (default, most common) %>
<button class="btn">
  <%= lucide_icon "plus", size: 16 %>
  Add Item
</button>

<%# Icon right (for forward navigation, external links) %>
<button class="btn">
  Next
  <%= lucide_icon "chevron-right", size: 16 %>
</button>

<%# Icon right for external links %>
<%= link_to "View docs", docs_url, target: "_blank", class: "btn" do %>
  Documentation
  <%= lucide_icon "external-link", size: 14 %>
<% end %>
```

---

## Animation

### Spin (Loading)

```erb
<%= lucide_icon "loader", size: 18, class: "animate-spin" %>
```

```css
.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
```

### Pulse (Notification)

```erb
<span class="notification-dot">
  <%= lucide_icon "bell", size: 18 %>
</span>
```

```css
.notification-dot {
  position: relative;
}
.notification-dot::after {
  content: "";
  position: absolute;
  top: 0;
  right: 0;
  width: 8px;
  height: 8px;
  background: var(--color-danger);
  border-radius: 50%;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
```

### Transition on Hover

```css
.icon-hover svg {
  transition: transform 0.15s ease;
}
.icon-hover:hover svg {
  transform: scale(1.1);
}
```

---

## Conditional Icons

### Boolean State

```erb
<%= lucide_icon(@post.published? ? "eye" : "eye-off", size: 14) %>
<%= lucide_icon(@user.verified? ? "check-circle" : "alert-circle", size: 14) %>
```

### Status Mapping

```ruby
# app/helpers/status_helper.rb
module StatusHelper
  STATUS_ICONS = {
    "active"   => { icon: "check-circle", class: "text-success" },
    "pending"  => { icon: "clock",        class: "text-warning" },
    "inactive" => { icon: "x-circle",     class: "text-muted" },
    "error"    => { icon: "alert-circle",  class: "text-danger" }
  }.freeze

  def status_icon(status, size: 14)
    config = STATUS_ICONS[status.to_s] || STATUS_ICONS["inactive"]
    tag.span(class: config[:class]) do
      lucide_icon(config[:icon], size: size)
    end
  end
end
```

```erb
<%= status_icon(@project.status) %> <%= @project.status.humanize %>
```

### Sort Direction

```erb
<%= link_to posts_path(sort: next_direction), class: "sort-header" do %>
  Name
  <% if params[:sort] == "asc" %>
    <%= lucide_icon "chevron-up", size: 14 %>
  <% elsif params[:sort] == "desc" %>
    <%= lucide_icon "chevron-down", size: 14 %>
  <% end %>
<% end %>
```

---

## Icon Helpers & Wrappers

### Application Helper Wrapper

Standardize icon usage across your app:

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def icon(name, size: 16, **options)
    lucide_icon(name, size: size, **options)
  end

  def icon_button(icon_name, label:, size: 18, **html_options)
    html_options[:class] = "btn-icon #{html_options[:class]}"
    html_options[:"aria-label"] = label
    tag.button(**html_options) do
      lucide_icon(icon_name, size: size)
    end
  end
end
```

```erb
<%= icon "home", size: 18 %>
<%= icon_button "x", label: "Close" %>
```

---

## Turbo & Stimulus Patterns

### Turbo Frame with Icon Button

```erb
<%= turbo_frame_tag "project_actions" do %>
  <%= link_to edit_project_path(@project),
    class: "btn-icon",
    aria: { label: "Edit project" },
    data: { turbo_frame: "project_form" } do %>
    <%= lucide_icon "edit", size: 16 %>
  <% end %>
<% end %>
```

### Stimulus Toggle

```erb
<div data-controller="toggle">
  <button data-action="click->toggle#toggle" aria-label="Toggle details">
    <%= lucide_icon "chevron-down", size: 16,
      data: { toggle_target: "icon" },
      class: "transition-transform" %>
  </button>

  <div data-toggle-target="content" class="hidden">
    <!-- Content -->
  </div>
</div>
```

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.iconTarget.classList.toggle("rotate-180")
  }
}
```

```css
.transition-transform { transition: transform 0.2s ease; }
.rotate-180 { transform: rotate(180deg); }
```

### Clipboard Copy with Icon Swap

```erb
<button data-controller="clipboard"
        data-action="click->clipboard#copy"
        data-clipboard-text-value="<%= @url %>"
        aria-label="Copy to clipboard">
  <span data-clipboard-target="icon">
    <%= lucide_icon "copy", size: 14 %>
  </span>
  <span data-clipboard-target="check" class="hidden">
    <%= lucide_icon "check", size: 14, class: "text-success" %>
  </span>
</button>
```

---

## Flash Messages with Icons

```ruby
# app/helpers/flash_helper.rb
module FlashHelper
  FLASH_ICONS = {
    "notice"  => "check-circle",
    "success" => "check-circle",
    "alert"   => "alert-circle",
    "error"   => "alert-circle",
    "warning" => "alert-triangle",
    "info"    => "info"
  }.freeze

  def flash_icon(type, size: 18)
    icon_name = FLASH_ICONS[type.to_s] || "info"
    lucide_icon(icon_name, size: size)
  end
end
```

```erb
<%# app/views/shared/_flash.html.erb %>
<% flash.each do |type, message| %>
  <div class="flash flash-<%= type %>" role="alert">
    <%= flash_icon(type) %>
    <span><%= message %></span>
    <button class="btn-icon" aria-label="Dismiss" data-action="click->flash#dismiss">
      <%= lucide_icon "x", size: 16 %>
    </button>
  </div>
<% end %>
```

```css
.flash {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 0.5rem;
}
.flash-notice, .flash-success { background: var(--color-success-bg); color: var(--color-success); }
.flash-alert, .flash-error    { background: var(--color-danger-bg);  color: var(--color-danger); }
.flash-warning                { background: var(--color-warning-bg); color: var(--color-warning); }
```

---

## Table Row Actions

```erb
<td class="actions">
  <%= link_to post_path(post), aria: { label: "View" } do %>
    <%= lucide_icon "eye", size: 16 %>
  <% end %>
  <%= link_to edit_post_path(post), aria: { label: "Edit" } do %>
    <%= lucide_icon "edit", size: 16 %>
  <% end %>
  <%= button_to post_path(post), method: :delete,
    class: "btn-icon text-danger",
    aria: { label: "Delete" },
    data: { turbo_confirm: "Delete this post?" } do %>
    <%= lucide_icon "trash", size: 16 %>
  <% end %>
</td>
```

```css
.actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.actions a,
.actions button {
  color: var(--color-muted);
  padding: 0.25rem;
}
.actions a:hover,
.actions button:hover {
  color: var(--color-default);
}
.actions .text-danger:hover {
  color: var(--color-danger);
}
```

---

## Dropdown Menus

```erb
<div data-controller="dropdown" class="dropdown">
  <button data-action="click->dropdown#toggle" aria-label="More options">
    <%= lucide_icon "more-vertical", size: 18 %>
  </button>

  <div data-dropdown-target="menu" class="dropdown-menu hidden">
    <%= link_to "#", class: "dropdown-item" do %>
      <%= lucide_icon "edit", size: 14 %> Edit
    <% end %>
    <%= link_to "#", class: "dropdown-item" do %>
      <%= lucide_icon "copy", size: 14 %> Duplicate
    <% end %>
    <hr class="dropdown-divider">
    <%= link_to "#", class: "dropdown-item text-danger" do %>
      <%= lucide_icon "trash", size: 14 %> Delete
    <% end %>
  </div>
</div>
```

---

## Form Icons

### Input with Leading Icon

```erb
<div class="input-with-icon">
  <%= lucide_icon "search", size: 16 %>
  <%= text_field_tag :query, params[:query], placeholder: "Search...", class: "input" %>
</div>
```

```css
.input-with-icon {
  position: relative;
  display: inline-flex;
  align-items: center;
}
.input-with-icon svg {
  position: absolute;
  left: 0.75rem;
  color: var(--color-muted);
  pointer-events: none;
}
.input-with-icon .input {
  padding-left: 2.5rem;
}
```

### Password Toggle

```erb
<div data-controller="password-toggle" class="input-with-icon-right">
  <%= password_field_tag :password, nil, data: { password_toggle_target: "input" } %>
  <button type="button" data-action="click->password-toggle#toggle"
          aria-label="Toggle password visibility" class="input-icon-right">
    <span data-password-toggle-target="showIcon">
      <%= lucide_icon "eye", size: 16 %>
    </span>
    <span data-password-toggle-target="hideIcon" class="hidden">
      <%= lucide_icon "eye-off", size: 16 %>
    </span>
  </button>
</div>
```

---

## Loading States

### Button Loading

```erb
<button data-controller="loading" data-action="click->loading#start"
        class="btn btn-primary">
  <span data-loading-target="default">
    <%= lucide_icon "save", size: 16 %> Save
  </span>
  <span data-loading-target="spinner" class="hidden">
    <%= lucide_icon "loader", size: 16, class: "animate-spin" %> Saving…
  </span>
</button>
```

### Turbo Loading Indicator

```erb
<turbo-frame id="content" data-turbo-loading-target="frame">
  <!-- content -->
</turbo-frame>

<%# Show spinner during Turbo navigation %>
<template data-turbo-loading-target="template">
  <div class="loading-state">
    <%= lucide_icon "loader", size: 24, class: "animate-spin" %>
  </div>
</template>
```

---

## Toggle Icons

### Expand/Collapse

```erb
<details>
  <summary class="with-icon">
    <%= lucide_icon "chevron-right", size: 16, class: "details-arrow" %>
    Section Title
  </summary>
  <div class="details-content">
    <!-- content -->
  </div>
</details>
```

```css
details .details-arrow {
  transition: transform 0.2s ease;
}
details[open] .details-arrow {
  transform: rotate(90deg);
}
```

### Favorite/Bookmark Toggle

```erb
<%= button_to toggle_favorite_path(@post), method: :patch do %>
  <% if @post.favorited_by?(current_user) %>
    <%= lucide_icon "star", size: 18, class: "fill-current text-warning" %>
  <% else %>
    <%= lucide_icon "star", size: 18 %>
  <% end %>
<% end %>
```

```css
/* Filled star: override fill for "active" state */
.fill-current {
  fill: currentColor;
}
```

---

## Responsive Icon Sizing

For icons that should scale with text:

```css
/* Size icon relative to font-size */
.icon-inline svg {
  width: 1em;
  height: 1em;
}
```

```erb
<h1 class="icon-inline">
  <%= lucide_icon "settings", size: 24 %> Settings
</h1>
```

This way the icon scales if the heading size changes via media queries.

---

## Troubleshooting

### "Unknown icon" Error

The icon name doesn't exist in the gem's bundled set. Possible causes:
- **Typo**: `lucide_icon "chevron_right"` → should be `"chevron-right"` (hyphens, not underscores)
- **Wrong casing**: `"ChevronRight"` → `"chevron-right"`
- **New icon not in gem**: The gem bundles a specific Lucide version. Check the gem version vs [lucide.dev/icons](https://lucide.dev/icons)
- **Fix**: `bundle update lucide-rails` to get latest icons

### Icons Not Showing

- Confirm the gem is in your Gemfile and bundled
- Check you're calling `lucide_icon` not `lucide_icon_tag` or any other variant
- Verify the icon name at [lucide.dev/icons](https://lucide.dev/icons)

### Icons Too Big / Too Small

- Always pass `size:` — don't rely on the 24px default
- Check if CSS is overriding: `svg { width: 100% }` will blow icons up
- Add explicit dimensions: `svg { width: auto; height: auto; }` to reset if needed

### Color Not Changing

- Icons use `stroke="currentColor"`, so they inherit from the CSS `color` property
- Make sure you're setting `color` on the parent, not `fill` or `stroke`
- Check CSS specificity — a more specific rule may be winning

### Icons Misaligned with Text

- Wrap in flexbox with `align-items: center` and `gap`
- Or use `vertical-align: -0.125em` for inline contexts
- Don't use `vertical-align: middle` — it aligns to the middle of the x-height, not the visual center

---

## Icon Name Gotchas

Common mistakes agents make with icon names:

| Wrong | Correct | Note |
|-------|---------|------|
| `chevronRight` | `chevron-right` | Always kebab-case |
| `chevron_right` | `chevron-right` | Hyphens, not underscores |
| `ChevronRight` | `chevron-right` | No PascalCase |
| `close` | `x` | Lucide uses `x` |
| `delete` | `trash` | Or `trash-2` |
| `warning` | `alert-triangle` | Lucide prefix pattern |
| `error` | `alert-circle` | Lucide prefix pattern |
| `success` | `check-circle` | Lucide prefix pattern |
| `add` | `plus` | Simple geometric name |
| `remove` | `minus` or `x` | Depends on context |
| `arrow-forward` | `arrow-right` | Lucide uses left/right/up/down |
| `notification` | `bell` | Object name, not concept |
| `account` | `user` | Object name, not concept |
| `dashboard` | `layout-dashboard` | Prefixed name |
| `document` | `file-text` | Lucide naming convention |
| `photo` | `image` | Lucide naming convention |

### Naming Patterns

Lucide follows consistent naming patterns:
- **Variants**: `file`, `file-text`, `file-plus`, `file-x`, `file-check`
- **Directions**: `chevron-left`, `chevron-right`, `chevron-up`, `chevron-down`
- **States**: `eye` / `eye-off`, `lock` / `unlock`, `bell` / `bell-off`
- **Sizes**: `circle`, `square` (some icons have `-2` variants with slight style differences: `trash` vs `trash-2`)
- **Compound**: `check-circle`, `alert-triangle`, `message-circle`, `arrow-up-right`

When in doubt, search [lucide.dev/icons](https://lucide.dev/icons).

---

## Performance Notes

### Inline SVGs Are Fast

The `lucide_icon` helper embeds SVGs directly in HTML. This means:
- **No extra HTTP requests** — icons render with the page
- **No flash of missing icons** — unlike icon fonts or lazy-loaded sprites
- **Cacheable via fragment caching** — the SVG is part of the cached HTML

### Repeated Icons

If the same icon appears 50+ times on a page (e.g., a long table with action icons), the HTML will contain 50 copies of that SVG. This is generally fine — SVG markup is small. If it becomes a measurable issue:

1. Use CSS-based solutions (icon fonts) for extreme repetition
2. Or use `<use>` references to a shared symbol (requires custom setup, not built into the gem)

For typical Rails views with 5–20 icons per page, inline SVGs are the right call.

### Fragment Caching

Icons cache naturally with Rails fragment caching:

```erb
<% cache @post do %>
  <h2><%= lucide_icon "file-text", size: 18 %> <%= @post.title %></h2>
<% end %>
```

No special handling needed.
