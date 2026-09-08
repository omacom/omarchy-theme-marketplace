---
name: rails-components
description: Expert guidance for building reusable UI components in Rails using partials, CSS classes, and helpers. Use when creating components, partials, reusable UI patterns, empty states, modals, cards, buttons, badges, alerts, data tables, or any component pattern. Covers decision framework for CSS-only vs partial vs helper vs ViewComponent, proper use of local_assigns, block yielding, capture for slots, variant patterns, and component galleries.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails server:*), Bash(bin/rails routes)
---

# Rails Component Patterns

Build reusable, self-contained, composable UI components using Rails primitives — partials, CSS classes, and helpers.

## Philosophy

**Core Principles:**
1. **Start with CSS classes** — don't reach for a partial when a class will do
2. **Self-contained** — each component owns its markup AND styles in one place
3. **Composable** — components nest and combine naturally
4. **Consistent** — same component = same markup = same appearance everywhere
5. **Progressive complexity** — graduate from CSS → partial → helper only when needed

**The Component Ladder:**
```
ViewComponent (gem)     ← Complex: encapsulated Ruby + template + tests
Helper method           ← Frequent: shorthand for common partials
Partial with locals     ← Structured: logic, slots, complex markup
CSS classes only        ← Simple: single element, few variants
```

**Always start at the bottom. Move up only when you feel pain.**

## When To Use This Skill

- Building new reusable UI components (buttons, cards, modals, etc.)
- Deciding between CSS classes, partials, helpers, or ViewComponent
- Creating empty states, alerts, badges, or data tables
- Refactoring repeated markup into shared components
- Setting up a component gallery for development
- Implementing variant patterns (sizes, colors, states)
- Organizing component files and styles

## Decision Framework

### Use CSS Classes When:
- Component is a single element or simple wrapper (`<button>`, `<span>`, `<div>`)
- Variants are purely visual (color, size, spacing)
- No conditional logic needed
- No content slots beyond inner text

**Examples:** buttons, badges, simple cards, form inputs, dividers

### Use Partials When:
- Component has conditional sections (show/hide based on args)
- Multiple named content areas (header, body, footer)
- Non-trivial markup structure (5+ elements)
- Default values or computed attributes needed

**Examples:** empty states, modals, complex cards, data tables, alerts with icons

### Use Helpers When:
- A partial is used very frequently (10+ call sites)
- You want a cleaner Ruby API: `ui_badge("Active", variant: :success)`
- Simple components where ERB render syntax feels heavy
- You want to compose multiple elements in Ruby

**Examples:** badges, status indicators, icon buttons, breadcrumbs

### Use ViewComponent When:
- Component needs its own unit tests
- Complex state logic that doesn't belong in a view
- Team is large and components need strict interfaces
- You're building a design system with dozens of components

**Skip ViewComponent** for most Rails apps. Partials + helpers cover 90% of needs.

## Instructions

### Step 1: Check Existing Components

**ALWAYS look for existing patterns first:**

```bash
# Find existing component partials
find app/views -path "*/components/*" -o -path "*/_component*" | head -20

# Find component CSS
find app/assets -name "*component*" -o -path "*/components/*" | head -20

# Find component helpers
rg "def ui_|def component_" app/helpers/

# Check for ViewComponent usage
ls app/components/ 2>/dev/null
rg "ViewComponent" Gemfile
```

**Match existing project conventions.** Consistency > your preference.

### Step 2: Choose the Right Approach

Reference the decision framework above. Ask:
1. Can this be done with just CSS classes? → Do that.
2. Does it need conditional logic or slots? → Partial.
3. Is it called from 10+ places with the same pattern? → Add a helper.
4. Does it need isolated tests and complex state? → ViewComponent.

### Step 3: File Organization

```
app/views/components/          # Shared component partials
├── _modal.html.erb
├── _empty_state.html.erb
├── _card.html.erb
├── _alert.html.erb
└── _data_table.html.erb

app/assets/stylesheets/components/   # One CSS file per component
├── buttons.css
├── badges.css
├── cards.css
├── modals.css
├── empty-states.css
├── alerts.css
└── tables.css

app/helpers/
└── component_helper.rb        # Helper shortcuts for common components
```

**Naming conventions:**
- Partials: `_snake_case.html.erb` in `app/views/components/`
- CSS files: `kebab-case.css` in `app/assets/stylesheets/components/`
- Helpers: `ui_component_name` prefix in `ComponentHelper`
- CSS classes: `.component-name`, `.component-name-element`, `.component-name--variant`

### Step 4: Build CSS-Only Components

For simple components, define CSS classes and use directly in templates:

```css
/* app/assets/stylesheets/components/buttons.css */
@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
    transition: background-color 0.15s;
  }

  .btn-primary { background: var(--color-primary); color: white; }
  .btn-secondary { background: var(--color-surface); border: 1px solid var(--color-border); }
  .btn-danger { background: var(--color-danger); color: white; }
  .btn-ghost { background: transparent; }
  .btn-sm { padding: 0.25rem 0.75rem; font-size: 0.875rem; }
  .btn-lg { padding: 0.75rem 1.5rem; }
  .btn-icon { padding: 0.5rem; }
}
```

```erb
<%# Usage — no partial needed %>
<button class="btn btn-primary">Save</button>
<button class="btn btn-danger btn-sm">Delete</button>
<%= link_to "View", post_path(@post), class: "btn btn-secondary" %>
```

### Step 5: Build Partial-Based Components

**Every partial MUST have a comment block documenting its interface:**

```erb
<%# app/views/components/_empty_state.html.erb %>
<%#
  Empty State Component

  Arguments:
    icon:        (String) Icon name — required
    title:       (String) Main heading — required
    description: (String, optional) Supporting text
    class:       (String, optional) Additional CSS classes

  Block: Optional action buttons
%>
<div class="empty-state <%= local_assigns[:class] %>">
  <div class="empty-state-icon">
    <%= lucide_icon icon, size: 48 %>
  </div>

  <h3 class="empty-state-title"><%= title %></h3>

  <% if local_assigns[:description] %>
    <p class="empty-state-description"><%= description %></p>
  <% end %>

  <% if block_given? %>
    <div class="empty-state-actions">
      <%= yield %>
    </div>
  <% end %>
</div>
```

**Key rules for partials:**

1. **Use `local_assigns[:key]`** to check for optional args — NOT `defined?` or `if key`
2. **Use `||=` for defaults** when the arg should have a fallback value
3. **Use `block_given?`** to check if a block was passed
4. **Use `yield`** for the primary content slot
5. **Use `capture`** for additional named slots

### Step 6: Implement Slots with Capture

For components with multiple content areas:

```erb
<%# app/views/components/_card.html.erb %>
<%#
  Card Component

  Arguments:
    header:  (String|HTML, optional) Header content — use capture for complex HTML
    footer:  (String|HTML, optional) Footer content — use capture for complex HTML
    class:   (String, optional) Additional CSS classes
    variant: (Symbol, optional) Card variant — :default, :stat, :interactive

  Block: Card body content (required)
%>
<%
  variant ||= :default
  css_class = ["card", ("card-#{variant}" unless variant == :default), local_assigns[:class]].compact.join(" ")
%>
<div class="<%= css_class %>">
  <% if local_assigns[:header] %>
    <div class="card-header"><%= header %></div>
  <% end %>

  <div class="card-body">
    <%= yield %>
  </div>

  <% if local_assigns[:footer] %>
    <div class="card-footer"><%= footer %></div>
  <% end %>
</div>
```

**Caller uses `capture` for rich slot content:**

```erb
<%= render "components/card",
    header: capture { tag.h3("Settings", class: "card-title") },
    footer: capture {
      link_to("Cancel", "#", class: "btn btn-secondary") +
      link_to("Save", "#", class: "btn btn-primary")
    } do %>
  <p>Card body content here.</p>
<% end %>
```

### Step 7: Add Helper Shortcuts

For frequently-used components, create helpers:

```ruby
# app/helpers/component_helper.rb
module ComponentHelper
  def ui_badge(text, variant: :muted)
    tag.span(text, class: "badge badge-#{variant}")
  end

  def ui_empty_state(title:, icon: nil, description: nil, &block)
    render("components/empty_state",
      title: title,
      icon: icon,
      description: description,
      &block)
  end

  def ui_alert(variant: :info, dismissible: false, &block)
    render("components/alert",
      variant: variant,
      dismissible: dismissible,
      &block)
  end
end
```

**Usage becomes clean:**

```erb
<%= ui_badge "Active", variant: :success %>
<%= ui_badge "Draft" %>

<%= ui_empty_state(
  icon: "inbox",
  title: "No messages",
  description: "Check back later") %>
```

### Step 8: Handle Variants

**CSS variants** for purely visual changes:

```css
/* Size variants */
.btn-sm { padding: 0.25rem 0.75rem; font-size: 0.875rem; }
.btn-lg { padding: 0.75rem 1.5rem; }

/* State variants */
.card-interactive:hover { border-color: var(--color-border-strong); }
.card-flush .card-body { padding: 0; }
```

**Partial argument variants** when markup changes:

```erb
<%# In the partial %>
<%
  variant ||= :info
  icon_name = { success: "check-circle", error: "alert-circle",
                warning: "alert-triangle", info: "info" }[variant.to_sym]
%>
<div class="alert alert-<%= variant %>" role="alert">
  <%= lucide_icon icon_name, size: 18 %>
  <span class="alert-content"><%= yield %></span>
</div>
```

### Step 9: Create a Component Gallery

**Essential for development.** Let anyone browse all components:

```ruby
# config/routes.rb
if Rails.env.development?
  get "components", to: "components#index"
end
```

```ruby
# app/controllers/components_controller.rb
class ComponentsController < ApplicationController
  layout "application"

  def index
  end
end
```

```erb
<%# app/views/components/index.html.erb %>
<div style="max-width: 48rem; margin: 2rem auto; padding: 0 1rem;">
  <h1>Component Gallery</h1>

  <h2>Buttons</h2>
  <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 2rem;">
    <button class="btn btn-primary">Primary</button>
    <button class="btn btn-secondary">Secondary</button>
    <button class="btn btn-danger">Danger</button>
    <button class="btn btn-ghost">Ghost</button>
    <button class="btn btn-sm">Small</button>
  </div>

  <h2>Badges</h2>
  <div style="display: flex; gap: 0.5rem; margin-bottom: 2rem;">
    <span class="badge badge-muted">Draft</span>
    <span class="badge badge-success">Active</span>
    <span class="badge badge-warning">Pending</span>
    <span class="badge badge-danger">Failed</span>
  </div>

  <h2>Empty States</h2>
  <%= render "components/empty_state",
      icon: "inbox",
      title: "No messages yet",
      description: "When you receive messages, they'll appear here." do %>
    <button class="btn btn-primary">Compose</button>
  <% end %>

  <h2>Alerts</h2>
  <%= render "components/alert", variant: :info do %>Info message<% end %>
  <%= render "components/alert", variant: :success do %>Success message<% end %>
  <%= render "components/alert", variant: :warning do %>Warning message<% end %>
  <%= render "components/alert", variant: :error do %>Error message<% end %>
</div>
```

## Anti-Patterns

1. **Partial for everything** — A `<span class="badge">` does NOT need `render "components/badge"`. CSS class is enough.
2. **Using `defined?(variable)`** — Always use `local_assigns[:variable]` in partials. `defined?` is unreliable.
3. **Global styles for component-specific things** — Component CSS lives in `components/`. Don't pollute `application.css`.
4. **Inconsistent naming** — Pick a convention and stick with it. `_empty_state.html.erb` not `_emptyState.html.erb`.
5. **God components** — If a partial takes 10+ arguments, split it into smaller components.
6. **Missing documentation** — Every partial needs a comment block listing its arguments.
7. **Passing HTML strings as args** — Use `capture { }` blocks or `yield`, never raw HTML strings.
8. **No gallery page** — If you can't see all your components in one place, they'll diverge.

## CSS Conventions

```css
/* Use @layer for specificity management */
@layer components {
  .component-name { /* base styles */ }
  .component-name-element { /* child element */ }
  .component-name--variant { /* BEM variant — OR use component-variant */ }
}
```

**Design token usage:**
```css
.component {
  color: var(--color-ink);           /* Text colors */
  background: var(--color-surface);  /* Backgrounds */
  border: 1px solid var(--color-border);  /* Borders */
  padding: var(--space-4);           /* Spacing scale */
  font-size: var(--text-sm);         /* Type scale */
  border-radius: var(--radius-md);   /* Border radius */
}
```

If the project uses design tokens/CSS custom properties, use them. If not, use consistent raw values.

## Quick Reference

### local_assigns Cheat Sheet

```erb
<%# Check if argument was passed (even if nil) %>
<% if local_assigns.key?(:title) %>

<%# Check if argument was passed AND is truthy %>
<% if local_assigns[:title] %>

<%# Default value %>
<% variant = local_assigns[:variant] || :default %>
<%# OR %>
<% variant ||= :default %>

<%# Pass-through CSS classes %>
<div class="component <%= local_assigns[:class] %>">
```

### Render Syntax

```erb
<%# Simple — no block %>
<%= render "components/empty_state", icon: "inbox", title: "Empty" %>

<%# With block %>
<%= render "components/modal", title: "Confirm" do %>
  <p>Are you sure?</p>
<% end %>

<%# With capture slots %>
<%= render "components/card",
    header: capture { tag.h3("Title") },
    footer: capture { tag.button("Save", class: "btn btn-primary") } do %>
  <p>Body</p>
<% end %>
```

### Common Component Templates

See `reference.md` in this skill directory for complete templates of:
- Buttons, Badges (CSS-only)
- Cards, Empty States, Alerts (partial)
- Modals with Stimulus (partial + JS)
- Data Tables (partial)
- Helper methods for all of the above
