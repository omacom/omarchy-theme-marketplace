# Component Patterns

Detailed CSS component examples — buttons, cards, badges, alerts, forms, and tables.

---

## Button Component

```css
/* components/forms.css or components/buttons.css */
@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    font-size: var(--text-sm);
    font-weight: var(--font-medium);
    line-height: var(--leading-tight);
    border-radius: var(--radius-lg);
    border: 1px solid transparent;
    cursor: pointer;
    transition: all var(--duration-fast) var(--ease-out);
  }

  .btn:focus-visible {
    outline: 2px solid var(--color-focus-ring);
    outline-offset: 2px;
  }

  /* Variants */
  .btn-primary {
    background: var(--color-primary);
    color: white;
  }
  .btn-primary:hover {
    background: var(--color-primary-hover);
  }

  .btn-secondary {
    background: var(--color-surface);
    border-color: var(--color-border);
    color: var(--color-ink);
  }
  .btn-secondary:hover {
    background: var(--color-surface-muted);
    border-color: var(--color-border-strong);
  }

  .btn-danger {
    background: var(--color-negative);
    color: white;
  }

  .btn-ghost {
    background: transparent;
    color: var(--color-ink-muted);
  }
  .btn-ghost:hover {
    background: var(--color-surface-muted);
    color: var(--color-ink);
  }

  /* Sizes */
  .btn-sm {
    padding: var(--space-1) var(--space-2);
    font-size: var(--text-xs);
  }
  .btn-lg {
    padding: var(--space-3) var(--space-6);
    font-size: var(--text-base);
  }

  /* States */
  .btn:disabled,
  .btn.is-loading {
    opacity: 0.6;
    pointer-events: none;
  }
}
```

## Card Component

```css
/* components/cards.css */
@layer components {
  .card {
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
    padding: var(--space-6);
  }

  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: var(--space-4);
    border-bottom: 1px solid var(--color-border-muted);
    margin-bottom: var(--space-4);
  }

  .card-title {
    font-size: var(--text-lg);
    font-weight: var(--font-semibold);
    color: var(--color-ink);
  }

  .card-body {
    color: var(--color-ink);
  }

  .card-footer {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding-top: var(--space-4);
    border-top: 1px solid var(--color-border-muted);
    margin-top: var(--space-4);
  }

  /* Variants */
  .card-sm { padding: var(--space-4); }
  .card-lg { padding: var(--space-8); }
  .card-flush { padding: 0; }
  .card-flush .card-header,
  .card-flush .card-body,
  .card-flush .card-footer { padding-left: var(--space-6); padding-right: var(--space-6); }

  /* Interactive card */
  .card-interactive {
    transition: border-color var(--duration-fast) var(--ease-out);
    cursor: pointer;
  }
  .card-interactive:hover {
    border-color: var(--color-border-strong);
  }
}
```

## Badge Component

```css
/* components/badges.css */
@layer components {
  .badge {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-0.5) var(--space-2);
    font-size: var(--text-xs);
    font-weight: var(--font-medium);
    border-radius: var(--radius-full);
    line-height: var(--leading-tight);
  }

  .badge-neutral {
    color: var(--color-ink-muted);
    background: var(--color-surface-muted);
  }

  .badge-positive {
    color: var(--color-positive);
    background: var(--color-positive-canvas);
  }

  .badge-negative {
    color: var(--color-negative);
    background: var(--color-negative-canvas);
  }

  .badge-warning {
    color: var(--color-warning);
    background: var(--color-warning-canvas);
  }

  /* Using color-mix for custom badge colors */
  .badge-feature {
    color: var(--color-purple-600);
    background: color-mix(in oklch, var(--color-purple-500) 15%, var(--color-surface));
  }
}
```

## Alert Component

```css
/* components/alerts.css */
@layer components {
  .alert {
    padding: var(--space-4);
    border-radius: var(--radius-lg);
    border: 1px solid;
    font-size: var(--text-sm);
  }

  .alert-info {
    color: var(--color-primary);
    background: light-dark(var(--color-blue-50), var(--color-blue-700));
    border-color: light-dark(var(--color-blue-200), var(--color-blue-700));
  }

  .alert-success {
    color: var(--color-positive);
    background: var(--color-positive-canvas);
    border-color: var(--color-positive-border);
  }

  .alert-danger {
    color: var(--color-negative);
    background: var(--color-negative-canvas);
    border-color: var(--color-negative-border);
  }

  .alert-warning {
    color: var(--color-warning);
    background: var(--color-warning-canvas);
    border-color: var(--color-warning-border);
  }
}
```

## Form Component

```css
/* components/forms.css */
@layer components {
  .form-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-1.5);
  }

  .form-label {
    font-size: var(--text-sm);
    font-weight: var(--font-medium);
    color: var(--color-ink);
  }

  .form-input {
    padding: var(--space-2) var(--space-3);
    font-size: var(--text-sm);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
    background: var(--color-surface);
    color: var(--color-ink);
    transition: border-color var(--duration-fast) var(--ease-out);
  }

  .form-input:focus {
    outline: none;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px var(--color-focus-ring);
  }

  .form-input::placeholder {
    color: var(--color-ink-subtle);
  }

  .form-help {
    font-size: var(--text-xs);
    color: var(--color-ink-muted);
  }

  .form-error {
    font-size: var(--text-xs);
    color: var(--color-negative);
  }

  .form-input.is-invalid {
    border-color: var(--color-negative);
  }

  /* Checkbox / radio */
  .form-check {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* Form layout */
  .form-stack {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .form-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: var(--space-4);
  }

  .form-actions {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding-top: var(--space-4);
  }
}
```

## Table Component

```css
/* components/tables.css */
@layer components {
  .table-container {
    overflow-x: auto;
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
  }

  .table {
    width: 100%;
    border-collapse: collapse;
    font-size: var(--text-sm);
  }

  .table th {
    text-align: left;
    padding: var(--space-3) var(--space-4);
    font-weight: var(--font-medium);
    color: var(--color-ink-muted);
    background: var(--color-surface-muted);
    border-bottom: 1px solid var(--color-border);
  }

  .table td {
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--color-border-muted);
    color: var(--color-ink);
  }

  .table tbody tr:last-child td {
    border-bottom: none;
  }

  .table-striped tbody tr:nth-child(even) {
    background: var(--color-surface-muted);
  }

  .table-hover tbody tr:hover {
    background: var(--color-surface-muted);
  }
}
```

## Rails Integration Patterns

### ERB Component Usage

```erb
<%# Compose components + utilities in views %>
<div class="card">
  <div class="card-header">
    <h3 class="card-title"><%= @project.name %></h3>
    <span class="badge badge-positive"><%= @project.status %></span>
  </div>
  <div class="card-body">
    <p class="text-muted text-sm"><%= @project.description %></p>
  </div>
  <div class="card-footer">
    <%= link_to "Edit", edit_project_path(@project), class: "btn btn-secondary btn-sm" %>
    <%= link_to "View", @project, class: "btn btn-primary btn-sm" %>
  </div>
</div>
```

### Flash Messages

```erb
<%# app/views/layouts/_flash.html.erb %>
<% flash.each do |type, message| %>
  <% alert_class = case type
    when "notice" then "alert-success"
    when "alert"  then "alert-danger"
    else "alert-info"
  end %>
  <div class="alert <%= alert_class %>" role="alert">
    <%= message %>
  </div>
<% end %>
```

### Form Builder Integration

```erb
<%= form_with(model: @user, class: "form-stack") do |f| %>
  <div class="form-group">
    <%= f.label :name, class: "form-label" %>
    <%= f.text_field :name, class: "form-input" %>
  </div>

  <div class="form-group">
    <%= f.label :email, class: "form-label" %>
    <%= f.email_field :email, class: "form-input" %>
    <span class="form-help">We'll never share your email.</span>
  </div>

  <div class="form-actions">
    <%= f.submit "Save", class: "btn btn-primary" %>
    <%= link_to "Cancel", users_path, class: "btn btn-secondary" %>
  </div>
<% end %>
```

### ViewComponent Integration

```ruby
# app/components/card_component.rb
class CardComponent < ViewComponent::Base
  def initialize(variant: nil, interactive: false)
    @variant = variant
    @interactive = interactive
  end

  def classes
    class_names(
      "card",
      "card-#{@variant}" => @variant,
      "card-interactive" => @interactive
    )
  end
end
```

```erb
<%# app/components/card_component.html.erb %>
<div class="<%= classes %>">
  <%= content %>
</div>
```

## Checklist: Adding a New Component

1. Create `app/assets/stylesheets/components/[name].css`
2. Wrap all rules in `@layer components { }`
3. Define base class: `.component-name`
4. Add subcomponents: `.component-name-header`, `.component-name-body`
5. Add variants: `.component-name-sm`, `.component-name-primary`
6. Use only design tokens (no hardcoded values)
7. Use semantic color tokens (not raw palette)
8. Verify dark mode works (toggle OS preference)
9. Test responsive behavior
10. Import in `application.css` if needed
