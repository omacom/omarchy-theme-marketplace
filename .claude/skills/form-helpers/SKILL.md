---
name: form-helpers
description: Expert guidance for building forms in Rails 8 applications. Use when creating forms, form_with, form helpers, nested forms, select helpers, file uploads, form builders, accepts_nested_attributes_for, fields_for, collection_select, grouped_collection_select, date/time selects, checkboxes, radio buttons, rich text areas, or any form-related view code. Covers model-backed forms, URL-based forms, complex nested attributes with _destroy, custom form builders, CSRF tokens, strong parameters for nested forms, and Stimulus integration.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails *), Bash(bundle exec rails *)
---

# Rails Form Helpers Expert

Build correct, modern forms in Rails 8 using `form_with` and associated helpers.

## When To Use This Skill

- Building any form in a Rails view (form_with, nested forms, selects, checkboxes)
- Adding nested attributes with fields_for and accepts_nested_attributes_for
- Choosing the right form helper (text_field, select, collection_select, etc.)
- Building custom form builders
- Integrating forms with Stimulus controllers

## The One Rule

**`form_with` is the ONLY form helper you use. Period.**

- ❌ `form_for` — deprecated since Rails 5.1. Do not use.
- ❌ `form_tag` — deprecated since Rails 5.1. Do not use.
- ✅ `form_with` — the one true form helper.

If you see `form_for` or `form_tag` in existing code, migrate it to `form_with` when touching that file. If you're writing new code, there is zero reason to use anything else.

## Two Modes of `form_with`

### Model-backed forms (most common)

```erb
<%= form_with model: @article do |form| %>
  <%= form.text_field :title %>
  <%= form.submit %>
<% end %>
```

Rails infers everything: action URL, HTTP method (POST for new, PATCH for persisted), field name scoping (`article[title]`), submit button text ("Create Article" vs "Update Article").

### URL-based forms (no model)

```erb
<%= form_with url: search_path, method: :get do |form| %>
  <%= form.search_field :query %>
  <%= form.submit "Search" %>
<% end %>
```

Use for search forms, external APIs, or any form not tied to a model.

## Instructions

### Step 1: Determine Form Type

| Scenario | Use |
|----------|-----|
| Creating/editing a model record | `form_with model: @record` |
| Search form | `form_with url: path, method: :get` |
| Form posting to external URL | `form_with url: "https://...", authenticity_token: false` |
| Namespaced resource (e.g. admin) | `form_with model: [:admin, @article]` |
| Nested resource | `form_with model: [@parent, @child]` |

### Step 2: Check Existing Patterns

**ALWAYS check the project's existing forms first:**

```bash
# Find existing form patterns
rg "form_with" app/views/ --type erb

# Check for custom form builders
rg "FormBuilder" app/ --type ruby

# Check for any deprecated form helpers (migration candidates)
rg "form_for\|form_tag" app/views/ --type erb
```

**Match existing project conventions.** If the app uses a custom form builder, use it.

### Step 3: Build the Form

Use the appropriate input helpers on the form builder object. Every helper takes the attribute name as its first argument.

**Common input helpers:**

```erb
<%= form_with model: @user do |form| %>
  <%= form.text_field :name %>
  <%= form.email_field :email %>
  <%= form.password_field :password %>
  <%= form.telephone_field :phone %>
  <%= form.url_field :website %>
  <%= form.textarea :bio, size: "70x5" %>
  <%= form.number_field :age, in: 18..120 %>
  <%= form.range_field :satisfaction, in: 1..10 %>
  <%= form.date_field :birthday %>
  <%= form.time_field :preferred_time %>
  <%= form.datetime_local_field :available_at %>
  <%= form.color_field :favorite_color %>
  <%= form.hidden_field :referrer, value: "homepage" %>
  <%= form.checkbox :terms_accepted %>
  <%= form.submit %>
<% end %>
```

### Step 4: Use Correct Select Helpers

Selects are where agents mess up most. Read the reference for full patterns.

**Static options:**
```erb
<%= form.select :status, ["Draft", "Published", "Archived"] %>
<%= form.select :status, [["Draft", "draft"], ["Published", "published"]] %>
```

**From a collection (belongs_to):**
```erb
<%= form.collection_select :city_id, City.order(:name), :id, :name %>
```

**With option groups:**
```erb
<%= form.grouped_collection_select :city_id, Country.order(:name), :cities, :name, :id, :name %>
```

**With prompt/include_blank:**
```erb
<%= form.select :category_id, categories, prompt: "Select a category" %>
<%= form.collection_select :author_id, Author.all, :id, :name, include_blank: "None" %>
```

### Step 5: Handle Nested Attributes Correctly

This is the hardest part of Rails forms. Follow this pattern exactly.

**1. Configure the model:**

```ruby
class Person < ApplicationRecord
  has_many :addresses, inverse_of: :person, dependent: :destroy
  accepts_nested_attributes_for :addresses, allow_destroy: true,
    reject_if: :all_blank
end
```

**2. Build empty children in controller:**

```ruby
def new
  @person = Person.new
  @person.addresses.build  # at least one empty set of fields
end

def edit
  @person = Person.find(params[:id])
  @person.addresses.build if @person.addresses.empty?
end
```

**3. Build the nested form:**

```erb
<%= form_with model: @person do |form| %>
  <%= form.text_field :name %>

  <h3>Addresses</h3>
  <%= form.fields_for :addresses do |address_form| %>
    <div class="nested-fields">
      <%= address_form.hidden_field :id %>
      <%= address_form.text_field :street %>
      <%= address_form.text_field :city %>
      <%= address_form.label :_destroy, "Remove" %>
      <%= address_form.checkbox :_destroy %>
    </div>
  <% end %>

  <%= form.submit %>
<% end %>
```

**4. Permit nested params:**

```ruby
def person_params
  params.expect(person: [
    :name,
    addresses_attributes: [[:id, :street, :city, :_destroy]]
  ])
end
```

**Critical notes on nested forms:**
- `fields_for` renders NOTHING if the association is empty — you MUST build at least one child
- `allow_destroy: true` requires the `_destroy` field AND permitting `:_destroy` in strong params
- `reject_if: :all_blank` prevents saving empty nested records
- Always include the hidden `:id` field for existing records (fields_for does this automatically)
- The double array `[[:id, :street, ...]]` in `params.expect` is intentional — it means "array of hashes with these keys"

### Step 6: Handle File Uploads

```erb
<%= form_with model: @user do |form| %>
  <%= form.file_field :avatar %>
  <%= form.submit %>
<% end %>
```

- `form_with` automatically sets `enctype="multipart/form-data"` when a `file_field` is present
- In the controller, `params[:user][:avatar]` is an `ActionDispatch::Http::UploadedFile`
- For production file handling, use Active Storage — don't roll your own

**Multiple files:**
```erb
<%= form.file_field :documents, multiple: true %>
```
Permit as array: `params.expect(user: [documents: []])`

### Step 7: Strong Parameters for Complex Forms

**Simple model:**
```ruby
params.expect(article: [:title, :body, :published])
```

**With nested attributes:**
```ruby
params.expect(person: [
  :name, :email,
  addresses_attributes: [[:id, :street, :city, :state, :zip, :_destroy]]
])
```

**With arrays (checkboxes, multi-select):**
```ruby
params.expect(article: [:title, tag_ids: []])
```

**With rich text (Action Text):**
```ruby
params.expect(article: [:title, :body])  # :body is the rich text attribute name
```

## Key Concepts

### CSRF Protection

Every non-GET form automatically includes an `authenticity_token` hidden field. This is Rails' CSRF protection. Don't disable it unless posting to an external service:

```erb
<%# External API - disable token %>
<%= form_with url: "https://external.api/webhook", authenticity_token: false do |form| %>
```

### HTTP Method Emulation

HTML forms only support GET and POST. Rails emulates PATCH, PUT, DELETE via a hidden `_method` field:

```erb
<%# This generates method="post" with a hidden _method="patch" %>
<%= form_with model: @article, method: :patch do |form| %>
```

For `form_with model: @article` on a persisted record, Rails sets PATCH automatically.

### Record Identification

`form_with model: @article` figures out:
- **New record?** → POST to `/articles` (create)
- **Persisted record?** → PATCH to `/articles/:id` (update)
- **Submit text** → "Create Article" or "Update Article"

This requires `resources :articles` in your routes.

### Namespaced & Nested Resources

```ruby
# Admin namespace
form_with model: [:admin, @article]
# → POST /admin/articles or PATCH /admin/articles/:id

# Nested resource
form_with model: [@magazine, @article]
# → POST /magazines/:magazine_id/articles

# Deep nesting
form_with model: [:admin, @magazine, @article]
```

## Custom Form Builders

When you repeat the same form patterns, create a custom builder:

```ruby
# app/form_builders/application_form_builder.rb
class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def text_field(attribute, options = {})
    label(attribute) + super(attribute, options.merge(class: "form-input"))
  end
end
```

Use it:
```erb
<%= form_with model: @user, builder: ApplicationFormBuilder do |form| %>
  <%= form.text_field :name %>  <%# Automatically includes label + CSS class %>
<% end %>
```

Or create a helper to use it by default:
```ruby
# app/helpers/application_helper.rb
def app_form_with(**options, &block)
  options[:builder] = ApplicationFormBuilder
  form_with(**options, &block)
end
```

## Rich Text (Action Text)

```erb
<%= form.rich_text_area :body %>
```

Requires Action Text to be installed (`rails action_text:install`). The attribute is declared on the model:

```ruby
class Article < ApplicationRecord
  has_rich_text :body
end
```

## Radio Buttons and Checkboxes

**Radio buttons** — user picks one:
```erb
<%= form.radio_button :flavor, "vanilla" %>
<%= form.label :flavor_vanilla, "Vanilla" %>
<%= form.radio_button :flavor, "chocolate" %>
<%= form.label :flavor_chocolate, "Chocolate" %>
```

**Collection radio buttons** — from a collection:
```erb
<%= form.collection_radio_buttons :city_id, City.all, :id, :name %>
```

**Checkboxes** — single boolean:
```erb
<%= form.checkbox :terms_accepted %>
<%= form.label :terms_accepted, "I accept the terms" %>
```

**Collection checkboxes** — has_many or HABTM:
```erb
<%= form.collection_checkboxes :interest_ids, Interest.all, :id, :name %>
```

Note: `checkbox` (not `check_box`) generates a hidden field with value "0" so unchecked boxes still submit a value.

## Date and Time Helpers

**Prefer HTML5 native inputs** (modern, mobile-friendly):
```erb
<%= form.date_field :born_on %>
<%= form.time_field :starts_at %>
<%= form.datetime_local_field :event_at %>
```

**Select-based date/time** (legacy, multi-select dropdowns):
```erb
<%= form.date_select :born_on %>
<%= form.time_select :starts_at %>
<%= form.datetime_select :event_at %>
```

Date selects produce multi-parameter attributes like `born_on(1i)`, `born_on(2i)`, `born_on(3i)`. Active Record knows how to reassemble these.

## Anti-Patterns

1. **Using `form_for` or `form_tag`** — always `form_with`
2. **Forgetting to build nested children** — `fields_for` renders nothing for empty associations
3. **Missing `_destroy` in strong params** — checkbox exists but destroy silently fails
4. **Using `select` for belongs_to without `_id` suffix** — the field name must be the foreign key
5. **Hardcoding form action URLs** — let `model:` infer them, or use route helpers
6. **Forgetting `allow_destroy: true`** on `accepts_nested_attributes_for`
7. **Not adding `reject_if: :all_blank`** — empty nested forms create blank records
8. **Manually setting `enctype` for file uploads** — `form_with` + `file_field` handles this
9. **Using `_tag` helpers inside a form builder block** — use the form builder methods instead
10. **Not permitting `id` in nested attributes** — needed to update (not duplicate) existing records

## Dynamically Adding/Removing Nested Fields

For adding nested fields dynamically (without page reload), use Stimulus:

```erb
<%# Render a hidden template for new fields %>
<template data-nested-form-target="template">
  <%= form.fields_for :addresses, Address.new, child_index: "NEW_RECORD" do |af| %>
    <div class="nested-fields" data-new-record>
      <%= af.text_field :street %>
      <%= af.text_field :city %>
      <%= af.hidden_field :_destroy, value: false, data: { nested_form_target: "destroy" } %>
      <button type="button" data-action="nested-form#remove">Remove</button>
    </div>
  <% end %>
</template>

<div data-nested-form-target="container">
  <%= form.fields_for :addresses do |af| %>
    <div class="nested-fields">
      <%= af.text_field :street %>
      <%= af.text_field :city %>
      <%= af.hidden_field :_destroy, value: false, data: { nested_form_target: "destroy" } %>
      <button type="button" data-action="nested-form#remove">Remove</button>
    </div>
  <% end %>
</div>

<button type="button" data-action="nested-form#add">Add Address</button>
```

The Stimulus controller replaces `NEW_RECORD` in the template with a unique timestamp to ensure unique parameter names. See reference.md for the full Stimulus controller code.

## Quick Reference: Input Helper → HTML Type

| Helper | HTML `type` |
|--------|------------|
| `text_field` | `text` |
| `email_field` | `email` |
| `password_field` | `password` |
| `telephone_field` | `tel` |
| `url_field` | `url` |
| `search_field` | `search` |
| `number_field` | `number` |
| `range_field` | `range` |
| `date_field` | `date` |
| `time_field` | `time` |
| `datetime_local_field` | `datetime-local` |
| `month_field` | `month` |
| `week_field` | `week` |
| `color_field` | `color` |
| `hidden_field` | `hidden` |
| `file_field` | `file` |
| `textarea` | `<textarea>` |
| `checkbox` | `checkbox` |
| `radio_button` | `radio` |

## Debugging Forms

```bash
# Check what params your form submits
# In controller:
Rails.logger.debug params.inspect

# Check generated HTML
# In browser dev tools, inspect the <form> element for:
# - action (correct URL?)
# - method (post?)
# - hidden _method field (patch/delete?)
# - authenticity_token present?
# - field names correct (model[attribute]?)

# Common param issues with nested forms:
# - addresses_attributes vs addresses (must be _attributes)
# - Missing id field (creates duplicates instead of updating)
# - _destroy not permitted (silently ignored)
```
