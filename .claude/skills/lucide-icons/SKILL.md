---
name: lucide-icons
description: Expert guidance for using Lucide icons in Rails applications via the lucide-rails gem. Use when adding icons, choosing icon names, styling SVG icons, making icons accessible, or building icon-based UI patterns (buttons, nav, badges, empty states). Triggers on "lucide", "icon", "lucide-rails", "SVG icon", "icon library", "lucide_icon", "feather icon", "inline SVG", "add an icon", "icon button", "icon name".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bundle add lucide-rails), Bash(bundle install), Bash(bin/rails test:*), Bash(bin/rails test)
---

# Lucide Icons in Rails

Render Lucide icons as inline SVGs via the `lucide-rails` gem. Icons use `currentColor` so they inherit text color automatically.

## When To Use This Skill

- Adding icons to a Rails view (buttons, nav, badges, empty states)
- Choosing the right Lucide icon name for a UI element
- Making icons accessible (decorative vs interactive)
- Styling or sizing SVG icons with CSS

## Philosophy

1. **Icons are decoration until they aren't** — Decorative icons need no label. Interactive icons (buttons, links) MUST have accessible text.
2. **Size intentionally** — Always pass `size:`. The default 24px is too large for most inline contexts.
3. **Let CSS handle color** — Icons inherit `currentColor`. Style the parent, not the SVG.
4. **Use the helper, never raw SVGs** — `lucide_icon` keeps icons consistent, cacheable, and updatable.
5. **kebab-case names only** — It's `"chevron-right"`, never `"chevronRight"` or `"ChevronRight"`.

## Installation

```ruby
# Gemfile
gem "lucide-rails"
```

```bash
bundle install
```

No JavaScript, no import maps, no asset pipeline config. The gem provides a Ruby helper that renders inline SVGs.

## Basic Usage

```erb
<%= lucide_icon "home", size: 18 %>
```

Renders:
```html
<svg width="18" height="18" viewBox="0 0 24 24" fill="none"
     stroke="currentColor" stroke-width="2"
     stroke-linecap="round" stroke-linejoin="round">
  <path d="..."></path>
</svg>
```

### Helper Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `size` | 24 | Width and height in pixels |
| `class` | nil | CSS classes |
| `stroke_width` | 2 | Stroke width (1–3 typical range) |

```erb
<%= lucide_icon "home", size: 16, class: "text-muted" %>
<%= lucide_icon "home", size: 24, stroke_width: 1.5 %>
```

**Any additional HTML attributes** are passed through to the `<svg>` element:

```erb
<%= lucide_icon "copy", size: 14, data: { action: "click->clipboard#copy" } %>
<%= lucide_icon "x", size: 18, aria: { label: "Close" } %>
```

## Size Guidelines

Pick size based on context. Be consistent within each context.

| Context | Size | When |
|---------|------|------|
| Badges, inline labels | 12px | Tight spaces, small text |
| Dismiss/close, inline actions | 14px | Body text companion |
| Buttons with text | 16px | Most common for actions |
| Navigation sidebar | 18px | Nav links, menu items |
| Card/list item icons | 20px | Content type indicators |
| Empty states, hero | 32–48px | Large decorative icons |

## Styling with CSS

### Color Inheritance

Icons stroke with `currentColor` — they inherit the parent's `color`:

```css
.nav-link { color: var(--color-muted); }
.nav-link:hover { color: var(--color-default); }
/* Icon color changes automatically on hover */
```

### Direct Icon Styling

When you need icon-specific colors, use a utility class on the parent or icon wrapper:

```css
.text-success { color: var(--color-positive); }
.text-danger  { color: var(--color-negative); }
.text-warning { color: var(--color-warning); }
.text-muted   { color: var(--color-muted); }
```

```erb
<span class="text-success"><%= lucide_icon "check", size: 14 %></span>
<span class="text-danger"><%= lucide_icon "alert-circle", size: 14 %></span>
```

### Stroke Width

Thinner strokes look more refined at larger sizes. Thicker strokes read better small.

```erb
<%= lucide_icon "settings", size: 48, stroke_width: 1.5 %>  <%# Large, elegant %>
<%= lucide_icon "check", size: 12, stroke_width: 2.5 %>     <%# Small, readable %>
```

### Dark Mode

Since icons use `currentColor`, they adapt to dark mode when your text colors do. No extra work needed if your color system uses CSS custom properties.

## Common Patterns

### Icon + Text Button

```erb
<button class="btn btn-primary">
  <%= lucide_icon "plus", size: 16 %>
  Create Project
</button>
```

```css
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}
```

### Icon-Only Button

```erb
<button class="btn-icon" aria-label="Close">
  <%= lucide_icon "x", size: 18 %>
</button>
```

```css
.btn-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.5rem;
}
```

**Icon-only buttons MUST have `aria-label`.**

### Navigation Link

```erb
<%= link_to dashboard_path, class: "nav-link" do %>
  <%= lucide_icon "layout-dashboard", size: 18 %>
  Dashboard
<% end %>
```

### Badge with Icon

```erb
<span class="badge">
  <%= lucide_icon "lock", size: 12 %>
  Restricted
</span>
```

```css
.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
}
```

### Empty State

```erb
<div class="empty-state">
  <%= lucide_icon "folder-plus", size: 48, stroke_width: 1.5 %>
  <h3>No projects yet</h3>
  <p>Create your first project to get started.</p>
</div>
```

```css
.empty-state {
  text-align: center;
  padding: 3rem 1rem;
}
.empty-state svg {
  color: var(--color-muted);
  margin-bottom: 1rem;
}
```

### Icon in Link (Turbo)

```erb
<%= link_to edit_post_path(@post), class: "action-link", data: { turbo_frame: "post_form" } do %>
  <%= lucide_icon "edit", size: 14 %>
  Edit
<% end %>
```

### Stimulus Integration

```erb
<button data-controller="clipboard" data-action="click->clipboard#copy"
        data-clipboard-text-value="<%= @invite_url %>">
  <%= lucide_icon "copy", size: 14 %>
  Copy Link
</button>
```

## Accessibility

### Rule: Decorative vs. Meaningful

**Decorative** — icon accompanies visible text. No extra markup needed:
```erb
<button>
  <%= lucide_icon "plus", size: 16 %> Add Item
</button>
```

**Meaningful** — icon is the only content. MUST add accessible text:
```erb
<%# Option 1: aria-label on the interactive element %>
<button aria-label="Close" class="btn-icon">
  <%= lucide_icon "x", size: 18 %>
</button>

<%# Option 2: sr-only span %>
<button class="btn-icon">
  <%= lucide_icon "x", size: 18 %>
  <span class="sr-only">Close</span>
</button>
```

### Screen Reader Only Class

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
```

### SVGs Are `aria-hidden` by Default

The `lucide_icon` helper renders SVGs that screen readers skip. This is correct — the accessible name belongs on the interactive parent element, not the icon.

## Common Icons by Use Case

### Navigation
| Icon Name | Use |
|-----------|-----|
| `home` | Home/Dashboard |
| `layout-dashboard` | Dashboard/Overview |
| `settings` | Settings |
| `users` | Team/People |
| `file-text` | Documents/Pages |
| `log-out` | Sign out |
| `log-in` | Sign in |
| `menu` | Hamburger menu |
| `search` | Search |

### Actions
| Icon Name | Use |
|-----------|-----|
| `plus` | Create/Add |
| `edit` | Edit/Modify |
| `trash` | Delete |
| `copy` | Copy to clipboard |
| `x` | Close/Dismiss |
| `check` | Confirm/Save |
| `eye` | View/Preview |
| `eye-off` | Hide |
| `download` | Download |
| `upload` | Upload |
| `external-link` | Open in new tab |

### Arrows & Chevrons
| Icon Name | Use |
|-----------|-----|
| `arrow-left` | Back |
| `arrow-right` | Forward |
| `chevron-down` | Expand/Dropdown |
| `chevron-right` | Next/Drill-in |
| `chevron-up` | Collapse |
| `arrow-up-right` | External/Outbound |

### Status & Feedback
| Icon Name | Use |
|-----------|-----|
| `check-circle` | Success |
| `alert-circle` | Error |
| `alert-triangle` | Warning |
| `info` | Information |
| `help-circle` | Help |
| `loader` | Loading (animate with CSS) |
| `lock` | Restricted/Private |
| `unlock` | Public/Open |

### Communication
| Icon Name | Use |
|-----------|-----|
| `mail` | Email |
| `bell` | Notifications |
| `message-circle` | Chat/Comments |
| `megaphone` | Announcements |
| `send` | Send message |

### Files & Content
| Icon Name | Use |
|-----------|-----|
| `file` | Generic file |
| `file-text` | Document |
| `folder` | Folder/Category |
| `folder-plus` | New folder |
| `image` | Image/Photo |
| `video` | Video |
| `link` | Link/URL |

### Social & Misc
| Icon Name | Use |
|-----------|-----|
| `github` | GitHub |
| `twitter` | Twitter/X |
| `globe` | Website/World |
| `calendar` | Date/Schedule |
| `clock` | Time/History |
| `star` | Favorite |
| `heart` | Like |
| `filter` | Filter |
| `sort-asc` | Sort ascending |
| `sort-desc` | Sort descending |

## Anti-Patterns

1. **Wrong icon name casing** — `"chevronRight"` → use `"chevron-right"` (kebab-case always)
2. **Missing size** — Don't rely on default 24px. Be explicit: `size: 16`
3. **Raw `<svg>` or `<img>` tags** — Always use `lucide_icon` helper
4. **Styling SVG directly** — Style the parent element's `color`, not the SVG's `stroke`
5. **Icon-only button without `aria-label`** — Screen readers can't describe it
6. **Inconsistent sizes** — Pick a size per context and stick to it
7. **Too many different icons** — Reuse the same icon for the same concept across your app
8. **Using icons without visible text when meaning is ambiguous** — A pencil icon might mean "edit" or "write." Add text or a tooltip.

## Finding Icons

Browse the full library at [lucide.dev/icons](https://lucide.dev/icons).

Search tips:
- Search by concept: "arrow", "file", "user", "check"
- Icons are named descriptively: `circle-check` not `checkmark-in-circle`
- Related icons share prefixes: `file`, `file-text`, `file-plus`, `file-x`
- If an icon doesn't exist in lucide-rails, the helper will raise an error at render time

## Reference

For detailed patterns, edge cases, and advanced usage, see [reference.md](./reference.md).
