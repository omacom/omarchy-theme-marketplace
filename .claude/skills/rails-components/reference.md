# Rails Components — Reference

Complete patterns, templates, and edge cases for building Rails UI components.

## Table of Contents
- [CSS-Only Components](#css-only-components)
- [Partial-Based Components](#partial-based-components)
- [Helper Methods — Full Reference](#helper-methods--full-reference)
- [Edge Cases & Gotchas](#edge-cases--gotchas)
- [Component Gallery — Full Setup](#component-gallery--full-setup)
- [Migration Guide: Repeated Markup → Component](#migration-guide-repeated-markup--component)
- [Naming Conventions Summary](#naming-conventions-summary)

## CSS-Only Components

### Buttons

```css
/* app/assets/stylesheets/components/buttons.css */
@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border: 1px solid transparent;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    line-height: 1.25rem;
    cursor: pointer;
    text-decoration: none;
    transition: background-color 0.15s, border-color 0.15s, color 0.15s;
    white-space: nowrap;
  }

  .btn:disabled, .btn[aria-disabled="true"] {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* Color variants */
  .btn-primary {
    background-color: var(--color-primary, #2563eb);
    color: white;
  }
  .btn-primary:hover { background-color: var(--color-primary-hover, #1d4ed8); }

  .btn-secondary {
    background-color: var(--color-surface, white);
    border-color: var(--color-border, #d1d5db);
    color: var(--color-ink, #111827);
  }
  .btn-secondary:hover { background-color: var(--color-surface-hover, #f9fafb); }

  .btn-danger {
    background-color: var(--color-danger, #dc2626);
    color: white;
  }
  .btn-danger:hover { background-color: var(--color-danger-hover, #b91c1c); }

  .btn-ghost {
    background: transparent;
    color: var(--color-ink-muted, #6b7280);
  }
  .btn-ghost:hover { background-color: var(--color-surface-hover, #f3f4f6); }

  /* Size variants */
  .btn-sm { padding: 0.25rem 0.75rem; font-size: 0.8125rem; }
  .btn-lg { padding: 0.75rem 1.5rem; font-size: 1rem; }
  .btn-icon { padding: 0.5rem; }

  /* Full width */
  .btn-block { width: 100%; }
}
```

**Usage patterns:**

```erb
<%# Standard buttons %>
<button class="btn btn-primary">Save Changes</button>
<button class="btn btn-secondary">Cancel</button>
<button class="btn btn-danger btn-sm">Delete</button>

<%# Link styled as button %>
<%= link_to "View Details", post_path(@post), class: "btn btn-secondary" %>

<%# Button with icon %>
<button class="btn btn-primary">
  <%= lucide_icon "plus", size: 16 %>
  Add Item
</button>

<%# Icon-only button %>
<button class="btn btn-ghost btn-icon" aria-label="Close">
  <%= lucide_icon "x", size: 18 %>
</button>

<%# Disabled state %>
<button class="btn btn-primary" disabled>Processing...</button>

<%# Submit button in form %>
<%= form.submit "Save", class: "btn btn-primary" %>
```

### Badges

```css
/* app/assets/stylesheets/components/badges.css */
@layer components {
  .badge {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.125rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 500;
    line-height: 1rem;
    white-space: nowrap;
  }

  .badge-muted {
    background-color: var(--color-surface-alt, #f3f4f6);
    color: var(--color-ink-muted, #6b7280);
  }

  .badge-success {
    background-color: var(--color-success-bg, #dcfce7);
    color: var(--color-success, #16a34a);
  }

  .badge-warning {
    background-color: var(--color-warning-bg, #fef3c7);
    color: var(--color-warning, #d97706);
  }

  .badge-danger {
    background-color: var(--color-danger-bg, #fee2e2);
    color: var(--color-danger, #dc2626);
  }

  .badge-info {
    background-color: var(--color-info-bg, #dbeafe);
    color: var(--color-info, #2563eb);
  }

  /* Dot indicator variant */
  .badge-dot::before {
    content: "";
    width: 0.375rem;
    height: 0.375rem;
    border-radius: 9999px;
    background-color: currentColor;
  }
}
```

**Usage:**

```erb
<span class="badge badge-success">Active</span>
<span class="badge badge-muted">Draft</span>
<span class="badge badge-warning badge-dot">Pending Review</span>
```

**Helper shortcut:**

```ruby
# app/helpers/component_helper.rb
def ui_badge(text, variant: :muted, dot: false)
  classes = ["badge", "badge-#{variant}", ("badge-dot" if dot)].compact.join(" ")
  tag.span(text, class: classes)
end
```

```erb
<%= ui_badge "Active", variant: :success %>
<%= ui_badge "Pending", variant: :warning, dot: true %>
```

---

## Partial-Based Components

### Empty State

```erb
<%# app/views/components/_empty_state.html.erb %>
<%#
  Empty State Component

  Arguments:
    icon:        (String) Icon name — required
    title:       (String) Main heading — required
    description: (String, optional) Supporting text below title
    compact:     (Boolean, optional) Reduced padding for inline usage
    class:       (String, optional) Additional CSS classes

  Block: Optional action area (buttons, links)
%>
<%
  compact = local_assigns[:compact] || false
%>
<div class="empty-state <%= 'empty-state-compact' if compact %> <%= local_assigns[:class] %>">
  <div class="empty-state-icon">
    <%= lucide_icon icon, size: (compact ? 32 : 48) %>
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

```css
/* app/assets/stylesheets/components/empty-states.css */
@layer components {
  .empty-state {
    text-align: center;
    padding: 3rem 1.5rem;
  }

  .empty-state-compact {
    padding: 1.5rem 1rem;
  }

  .empty-state-icon {
    color: var(--color-ink-subtle, #9ca3af);
    margin-bottom: 1rem;
  }

  .empty-state-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-ink, #111827);
    margin: 0 0 0.5rem;
  }

  .empty-state-description {
    color: var(--color-ink-muted, #6b7280);
    margin: 0 0 1.5rem;
    max-width: 24rem;
    margin-inline: auto;
  }

  .empty-state-actions {
    display: flex;
    justify-content: center;
    gap: 0.75rem;
  }
}
```

**Usage examples:**

```erb
<%# Full empty state with action %>
<%= render "components/empty_state",
    icon: "folder-plus",
    title: "No projects yet",
    description: "Create your first project to get started." do %>
  <%= link_to "Create Project", new_project_path, class: "btn btn-primary" %>
<% end %>

<%# Minimal — no description, no actions %>
<%= render "components/empty_state",
    icon: "search",
    title: "No results found" %>

<%# Compact variant for sidebar/inline %>
<%= render "components/empty_state",
    icon: "bell",
    title: "No notifications",
    compact: true %>

<%# Multiple actions %>
<%= render "components/empty_state",
    icon: "users",
    title: "No team members",
    description: "Invite people to collaborate on this project." do %>
  <%= link_to "Invite by Email", new_invitation_path, class: "btn btn-primary" %>
  <%= link_to "Import from CSV", import_path, class: "btn btn-secondary" %>
<% end %>
```

### Alert / Flash

```erb
<%# app/views/components/_alert.html.erb %>
<%#
  Alert Component

  Arguments:
    variant:     (Symbol, optional) :info (default), :success, :warning, :error
    dismissible: (Boolean, optional) Show close button — default false
    icon:        (String, optional) Override default icon

  Block: Alert message content (required)
%>
<%
  variant ||= :info
  dismissible ||= false
  default_icons = { success: "check-circle", error: "alert-circle",
                    warning: "alert-triangle", info: "info" }
  icon_name = local_assigns[:icon] || default_icons[variant.to_sym] || "info"
%>
<div class="alert alert-<%= variant %>" role="alert"
     <% if dismissible %>data-controller="alert"<% end %>>
  <div class="alert-icon">
    <%= lucide_icon icon_name, size: 18 %>
  </div>
  <div class="alert-content"><%= yield %></div>
  <% if dismissible %>
    <button type="button" class="alert-dismiss" data-action="click->alert#dismiss"
            aria-label="Dismiss">
      <%= lucide_icon "x", size: 14 %>
    </button>
  <% end %>
</div>
```

```css
/* app/assets/stylesheets/components/alerts.css */
@layer components {
  .alert {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    border: 1px solid;
    font-size: 0.875rem;
    line-height: 1.25rem;
  }

  .alert-info {
    background-color: var(--color-info-bg, #eff6ff);
    border-color: var(--color-info-border, #bfdbfe);
    color: var(--color-info, #1d4ed8);
  }

  .alert-success {
    background-color: var(--color-success-bg, #f0fdf4);
    border-color: var(--color-success-border, #bbf7d0);
    color: var(--color-success, #16a34a);
  }

  .alert-warning {
    background-color: var(--color-warning-bg, #fffbeb);
    border-color: var(--color-warning-border, #fde68a);
    color: var(--color-warning, #d97706);
  }

  .alert-error {
    background-color: var(--color-danger-bg, #fef2f2);
    border-color: var(--color-danger-border, #fecaca);
    color: var(--color-danger, #dc2626);
  }

  .alert-icon { flex-shrink: 0; padding-top: 0.0625rem; }
  .alert-content { flex: 1; }
  .alert-dismiss {
    flex-shrink: 0;
    background: none;
    border: none;
    cursor: pointer;
    opacity: 0.5;
    padding: 0.125rem;
  }
  .alert-dismiss:hover { opacity: 1; }
}
```

**Flash message integration:**

```erb
<%# app/views/layouts/_flashes.html.erb %>
<% flash.each do |type, message| %>
  <%
    variant = case type.to_s
      when "notice", "success" then :success
      when "alert", "error" then :error
      when "warning" then :warning
      else :info
    end
  %>
  <%= render "components/alert", variant: variant, dismissible: true do %>
    <%= message %>
  <% end %>
<% end %>
```

### Modal

```erb
<%# app/views/components/_modal.html.erb %>
<%#
  Modal Component

  Arguments:
    id:    (String) Unique modal ID — required
    title: (String) Modal heading — required
    size:  (Symbol, optional) :sm, :md (default), :lg

  Block: Modal body content (required)

  Requires: Stimulus modal_controller
%>
<%
  size ||= :md
%>
<div id="<%= id %>"
     class="modal"
     data-controller="modal"
     data-modal-open-value="false"
     aria-hidden="true">
  <div class="modal-backdrop" data-action="click->modal#close"></div>
  <div class="modal-dialog modal-<%= size %>">
    <div class="modal-header">
      <h3 class="modal-title"><%= title %></h3>
      <button type="button" class="btn btn-ghost btn-icon"
              data-action="click->modal#close" aria-label="Close">
        <%= lucide_icon "x", size: 18 %>
      </button>
    </div>
    <div class="modal-body">
      <%= yield %>
    </div>
  </div>
</div>
```

**Stimulus controller:**

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { open: { type: Boolean, default: false } }

  connect() {
    if (this.openValue) this.open()
  }

  open() {
    this.element.classList.add("modal-open")
    this.element.setAttribute("aria-hidden", "false")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.element.classList.remove("modal-open")
    this.element.setAttribute("aria-hidden", "true")
    document.body.style.overflow = ""
  }

  // Allow opening from outside: data-action="click->modal#open"
  // by targeting the modal element
}
```

**Usage:**

```erb
<%# Trigger button %>
<button class="btn btn-danger"
        data-action="click->modal#open"
        data-modal-outlet="#confirm-delete">
  Delete
</button>

<%# Modal definition %>
<%= render "components/modal", id: "confirm-delete", title: "Confirm Deletion" do %>
  <p>This action cannot be undone. Are you sure?</p>
  <div class="modal-actions">
    <button class="btn btn-secondary" data-action="click->modal#close">Cancel</button>
    <%= button_to "Delete", post_path(@post), method: :delete, class: "btn btn-danger" %>
  </div>
<% end %>
```

### Card (Complex)

```erb
<%# app/views/components/_card.html.erb %>
<%#
  Card Component

  Arguments:
    header:  (String|HTML, optional) Card header — use capture {} for complex content
    footer:  (String|HTML, optional) Card footer — use capture {} for complex content
    variant: (Symbol, optional) :default, :stat, :interactive, :flush
    class:   (String, optional) Additional CSS classes
    id:      (String, optional) Element ID

  Block: Card body content (required)
%>
<%
  variant ||= :default
  css = ["card"]
  css << "card-#{variant}" unless variant == :default
  css << local_assigns[:class] if local_assigns[:class]
%>
<div class="<%= css.join(' ') %>" <% if local_assigns[:id] %>id="<%= id %>"<% end %>>
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

**Usage with capture for multi-slot content:**

```erb
<%= render "components/card",
    variant: :interactive,
    header: capture {
      tag.div(class: "card-header-row") do
        tag.h3("Recent Activity", class: "card-title") +
        ui_badge("12 new", variant: :info)
      end
    },
    footer: capture {
      link_to("View All →", activities_path, class: "text-link")
    } do %>
  <ul class="activity-list">
    <% @activities.each do |activity| %>
      <li><%= activity.description %></li>
    <% end %>
  </ul>
<% end %>
```

### Data Table

```erb
<%# app/views/components/_data_table.html.erb %>
<%#
  Data Table Component

  Arguments:
    columns:    (Array<Hash>) Column definitions — required
                Each: { key: Symbol, label: String, class: String (optional) }
    records:    (ActiveRecord::Relation|Array) Data to display — required
    empty_icon: (String, optional) Icon for empty state
    empty_text: (String, optional) Text for empty state

  Block: Optional — renders for each record. Yields |record|.
         If no block, uses column[:key] to extract values.
%>
<% if records.empty? %>
  <%= render "components/empty_state",
      icon: local_assigns[:empty_icon] || "database",
      title: local_assigns[:empty_text] || "No records found" %>
<% else %>
  <div class="table-container">
    <table class="data-table">
      <thead>
        <tr>
          <% columns.each do |col| %>
            <th class="<%= col[:class] %>"><%= col[:label] %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <% if block_given? %>
          <% records.each do |record| %>
            <%= yield record %>
          <% end %>
        <% else %>
          <% records.each do |record| %>
            <tr>
              <% columns.each do |col| %>
                <td class="<%= col[:class] %>"><%= record.public_send(col[:key]) %></td>
              <% end %>
            </tr>
          <% end %>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

**Usage — simple (auto-render columns):**

```erb
<%= render "components/data_table",
    columns: [
      { key: :name, label: "Name" },
      { key: :email, label: "Email" },
      { key: :created_at, label: "Joined", class: "text-muted" }
    ],
    records: @users,
    empty_icon: "users",
    empty_text: "No users yet" %>
```

**Usage — custom rows with block:**

```erb
<%= render "components/data_table",
    columns: [
      { key: :name, label: "Name" },
      { key: :status, label: "Status" },
      { key: :actions, label: "", class: "text-right" }
    ],
    records: @projects do |project| %>
  <tr>
    <td><%= link_to project.name, project_path(project) %></td>
    <td><%= ui_badge project.status, variant: project.active? ? :success : :muted %></td>
    <td class="text-right">
      <%= link_to "Edit", edit_project_path(project), class: "btn btn-ghost btn-sm" %>
    </td>
  </tr>
<% end %>
```

---

## Helper Methods — Full Reference

```ruby
# app/helpers/component_helper.rb
module ComponentHelper
  # Badge — CSS-only, helper for convenience
  def ui_badge(text, variant: :muted, dot: false)
    classes = ["badge", "badge-#{variant}", ("badge-dot" if dot)].compact.join(" ")
    tag.span(text, class: classes)
  end

  # Empty state — wraps the partial
  def ui_empty_state(title:, icon: nil, description: nil, **opts, &block)
    render("components/empty_state",
      title: title, icon: icon, description: description, **opts, &block)
  end

  # Alert — wraps the partial
  def ui_alert(variant: :info, dismissible: false, **opts, &block)
    render("components/alert",
      variant: variant, dismissible: dismissible, **opts, &block)
  end

  # Status badge — maps model status to badge variant
  def ui_status_badge(status)
    variant = case status.to_s
      when "active", "published", "complete" then :success
      when "pending", "review", "processing" then :warning
      when "failed", "rejected", "error" then :danger
      when "info", "new" then :info
      else :muted
    end
    ui_badge(status.to_s.humanize, variant: variant)
  end

  # Icon button — common pattern
  def ui_icon_button(icon, label:, **html_opts)
    html_opts[:class] = ["btn btn-ghost btn-icon", html_opts[:class]].compact.join(" ")
    html_opts[:"aria-label"] = label
    tag.button(**html_opts) { lucide_icon(icon, size: 18) }
  end
end
```

---

## Edge Cases & Gotchas

### 1. local_assigns vs defined? vs nil checks

```erb
<%# WRONG — defined? is unreliable in partials %>
<% if defined?(description) %>

<%# WRONG — fails if description was explicitly passed as nil %>
<% if description %>

<%# CORRECT — checks if the key was passed at all %>
<% if local_assigns[:description] %>

<%# CORRECT — checks if passed AND truthy %>
<% if local_assigns[:description].present? %>

<%# CORRECT — default value %>
<% variant = local_assigns[:variant] || :default %>
<%# OR (equivalent for non-boolean args) %>
<% variant ||= :default %>
```

**Why `||=` works:** In partials, unpassed locals are `nil`, so `variant ||= :default` sets the default. But `||=` fails for boolean args where `false` is valid — use `local_assigns.fetch(:dismissible, false)` instead.

### 2. Boolean arguments

```erb
<%# WRONG — if dismissible is false, this sets it to true %>
<% dismissible ||= true %>

<%# CORRECT — preserves explicit false %>
<% dismissible = local_assigns.fetch(:dismissible, true) %>

<%# Also correct — check if key exists %>
<% dismissible = local_assigns.key?(:dismissible) ? dismissible : true %>
```

### 3. Passing additional HTML attributes

```erb
<%# Pattern: merge data-* and aria-* attributes %>
<%
  html_attrs = {
    class: ["card", local_assigns[:class]].compact.join(" "),
    id: local_assigns[:id],
    data: local_assigns[:data] || {},
    **local_assigns.fetch(:html, {})
  }.compact
%>
<div <%= tag.attributes(html_attrs) %>>
```

### 4. Capture gotcha — returns SafeBuffer

```erb
<%# capture returns ActiveSupport::SafeBuffer, not String %>
<%# This means HTML is already escaped — don't double-escape %>

<%# CORRECT %>
<%= render "components/card", header: capture { tag.h3("Title") } do %>

<%# WRONG — passes a raw string, may break with special chars %>
<%= render "components/card", header: "<h3>Title</h3>" do %>
```

### 5. Nested components

Components should compose naturally:

```erb
<%= render "components/card", header: "User Settings" do %>
  <%= render "components/alert", variant: :warning do %>
    Please verify your email address.
  <% end %>

  <%= form_with model: @user do |f| %>
    <%# form fields %>
  <% end %>

  <%= render "components/empty_state",
      icon: "key",
      title: "No API keys",
      compact: true do %>
    <%= link_to "Generate Key", new_api_key_path, class: "btn btn-sm btn-primary" %>
  <% end %>
<% end %>
```

### 6. Turbo Frame compatibility

Components inside Turbo Frames work naturally. For modals that should escape the frame:

```erb
<%# Modal should target _top to avoid frame nesting %>
<%= render "components/modal", id: "my-modal", title: "Edit" do %>
  <%= form_with model: @record, data: { turbo_frame: "_top" } do |f| %>
    <%# ... %>
  <% end %>
<% end %>
```

### 7. Component-scoped Stimulus controllers

When a component needs JavaScript, the Stimulus controller lives alongside it logically:

```
app/javascript/controllers/
├── modal_controller.js      # For modal component
├── alert_controller.js      # For dismissible alerts
└── dropdown_controller.js   # For dropdown component
```

The partial references the controller via `data-controller`:

```erb
<div data-controller="alert" class="alert">
  <%# ... %>
  <button data-action="click->alert#dismiss">×</button>
</div>
```

---

## Component Gallery — Full Setup

### Route

```ruby
# config/routes.rb
if Rails.env.development?
  get "components", to: "components#index"
  get "components/:name", to: "components#show", as: :component
end
```

### Controller

```ruby
# app/controllers/components_controller.rb
class ComponentsController < ApplicationController
  skip_before_action :authenticate_user! if method_defined?(:authenticate_user!)

  layout "application"

  def index
  end

  def show
    render "components/gallery/#{params[:name]}"
  rescue ActionView::MissingTemplate
    render plain: "Component '#{params[:name]}' not found", status: :not_found
  end
end
```

### Gallery page

```erb
<%# app/views/components/index.html.erb %>
<% content_for :title, "Component Gallery" %>

<div style="max-width: 48rem; margin: 2rem auto; padding: 0 1rem;">
  <h1>Component Gallery</h1>
  <p class="text-muted">All reusable UI components. Development only.</p>

  <hr>

  <h2 id="buttons">Buttons</h2>
  <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 1rem;">
    <button class="btn btn-primary">Primary</button>
    <button class="btn btn-secondary">Secondary</button>
    <button class="btn btn-danger">Danger</button>
    <button class="btn btn-ghost">Ghost</button>
  </div>
  <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 2rem;">
    <button class="btn btn-primary btn-sm">Small</button>
    <button class="btn btn-primary">Medium</button>
    <button class="btn btn-primary btn-lg">Large</button>
    <button class="btn btn-primary" disabled>Disabled</button>
  </div>

  <h2 id="badges">Badges</h2>
  <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 2rem;">
    <span class="badge badge-muted">Muted</span>
    <span class="badge badge-success">Success</span>
    <span class="badge badge-warning">Warning</span>
    <span class="badge badge-danger">Danger</span>
    <span class="badge badge-info">Info</span>
    <span class="badge badge-success badge-dot">With Dot</span>
  </div>

  <h2 id="alerts">Alerts</h2>
  <div style="display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 2rem;">
    <%= render "components/alert", variant: :info do %>
      This is an informational message.
    <% end %>
    <%= render "components/alert", variant: :success do %>
      Changes saved successfully.
    <% end %>
    <%= render "components/alert", variant: :warning do %>
      Your trial expires in 3 days.
    <% end %>
    <%= render "components/alert", variant: :error, dismissible: true do %>
      Something went wrong. Please try again.
    <% end %>
  </div>

  <h2 id="empty-states">Empty States</h2>
  <div style="border: 1px dashed #d1d5db; border-radius: 0.5rem; margin-bottom: 2rem;">
    <%= render "components/empty_state",
        icon: "inbox",
        title: "No messages",
        description: "When you receive messages, they'll show up here." do %>
      <button class="btn btn-primary">Compose Message</button>
    <% end %>
  </div>

  <h2 id="cards">Cards</h2>
  <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; margin-bottom: 2rem;">
    <%= render "components/card", header: "Simple Card" do %>
      <p>Basic card with header and body.</p>
    <% end %>
    <%= render "components/card",
        header: capture { tag.h3("With Footer", class: "card-title") },
        footer: capture { link_to "Action →", "#", class: "text-link" } do %>
      <p>Card with header and footer.</p>
    <% end %>
  </div>
</div>
```

---

## Migration Guide: Repeated Markup → Component

When you spot duplicated UI patterns, extract to a component:

### Step 1: Find repetition

```bash
# Find similar markup patterns
rg "empty-state" app/views/ --files-with-matches
rg "class=\"card\"" app/views/ --files-with-matches
rg "class=\"badge" app/views/ --files-with-matches
```

### Step 2: Identify the interface

Look at all usages and find:
- What's always the same? → Goes in the component template
- What varies? → Becomes arguments or slots
- What's sometimes present? → Optional args with `local_assigns`

### Step 3: Create the component

1. Write the partial in `app/views/components/`
2. Write its CSS in `app/assets/stylesheets/components/`
3. Document the interface in a comment block
4. Add to the gallery page

### Step 4: Replace usages

Find-and-replace old markup with `render` calls. Test each page.

### Step 5: Optional — add helper

If you end up with 10+ render calls for the same component, add a helper method.

---

## Naming Conventions Summary

| Thing | Convention | Example |
|-------|-----------|---------|
| Partial file | `_snake_case.html.erb` | `_empty_state.html.erb` |
| Partial path | `components/name` | `render "components/empty_state"` |
| CSS file | `kebab-case.css` | `empty-states.css` |
| CSS class (base) | `.component-name` | `.empty-state` |
| CSS class (element) | `.component-name-element` | `.empty-state-title` |
| CSS class (variant) | `.component-name-variant` | `.card-interactive` |
| Helper method | `ui_component_name` | `ui_empty_state(...)` |
| Stimulus controller | `component_controller.js` | `modal_controller.js` |
| Gallery route | `/components` | `get "components"` |
