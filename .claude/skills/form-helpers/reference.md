# Form Helpers Reference

Detailed patterns, examples, and edge cases for Rails 8 form helpers.

## Table of Contents

- [form_with: Complete API](#form_with-complete-api)
- [Select Helpers Deep Dive](#select-helpers-deep-dive)
- [Nested Attributes Patterns](#nested-attributes-patterns)
- [File Uploads](#file-uploads)
- [Custom Form Builders](#custom-form-builders)
- [Params Naming Conventions](#params-naming-conventions)
- [Dynamic Nested Fields with Stimulus](#dynamic-nested-fields-with-stimulus)
- [Edge Cases and Gotchas](#edge-cases-and-gotchas)
- [Migration from form_for / form_tag](#migration-from-form_for--form_tag)

---

## form_with: Complete API

### All Options

```ruby
form_with(
  model: nil,           # ActiveRecord object or array for namespaced/nested
  url: nil,             # Override the form action URL
  scope: nil,           # Override the param key (e.g., scope: :search)
  method: :post,        # HTTP method (:get, :post, :patch, :put, :delete)
  format: nil,          # Request format (e.g., :json)
  namespace: nil,       # Namespace for form element IDs
  builder: nil,         # Custom FormBuilder class
  html: {},             # Additional HTML attributes for <form>
  id: nil,              # Form element ID
  class: nil,           # CSS class
  data: {},             # Data attributes
  authenticity_token: nil,  # Override or disable (false) CSRF token
  multipart: false,     # Force multipart/form-data (auto-set by file_field)
  local: true           # Always true in Rails 7+ (Turbo handles remote)
)
```

### Model-Backed Examples

```erb
<%# New record → POST /articles %>
<%= form_with model: Article.new do |form| %>

<%# Existing record → PATCH /articles/42 %>
<%= form_with model: @article do |form| %>

<%# Namespaced → POST /admin/articles %>
<%= form_with model: [:admin, @article] do |form| %>

<%# Nested resource → POST /authors/1/books %>
<%= form_with model: [@author, @book] do |form| %>

<%# Override URL %>
<%= form_with model: @article, url: custom_path do |form| %>

<%# Override scope (param key) %>
<%= form_with model: @article, scope: :post do |form| %>
<%# Fields named as post[title] instead of article[title] %>

<%# With Turbo Frame %>
<%= form_with model: @article, data: { turbo_frame: "articles" } do |form| %>
```

### URL-Based Examples

```erb
<%# Search form (GET) %>
<%= form_with url: search_path, method: :get do |form| %>
  <%= form.search_field :q %>
  <%= form.submit "Search" %>
<% end %>

<%# Scoped params without model %>
<%= form_with url: filter_path, scope: :filter, method: :get do |form| %>
  <%= form.text_field :keyword %>
  <%= form.select :category, ["A", "B", "C"] %>
<% end %>
<%# Params: filter[keyword], filter[category] %>

<%# External API (no CSRF token) %>
<%= form_with url: "https://api.example.com/submit", authenticity_token: false do |form| %>
```

### HTML Attributes

```erb
<%= form_with model: @user,
    id: "user-form",
    class: "space-y-4",
    data: { controller: "form-validation", turbo_confirm: "Are you sure?" },
    html: { novalidate: true } do |form| %>
```

---

## Select Helpers Deep Dive

### form.select

The most flexible select helper. Accepts many option formats.

```erb
<%# Simple array of strings (value == label) %>
<%= form.select :status, ["Draft", "Published", "Archived"] %>

<%# Array of [label, value] pairs %>
<%= form.select :status, [["Draft", "draft"], ["Published", "published"]] %>

<%# Hash (label => value) %>
<%= form.select :role, { "Admin" => "admin", "Editor" => "editor", "Viewer" => "viewer" } %>

<%# With blank/prompt option %>
<%= form.select :category, categories, include_blank: true %>
<%= form.select :category, categories, include_blank: "Select one..." %>
<%= form.select :category, categories, prompt: "Please select" %>
<%# include_blank: always shown. prompt: only shown when no value selected %>

<%# Pre-selected value %>
<%= form.select :city, cities, selected: "chicago" %>

<%# Disabled options %>
<%= form.select :size, sizes, disabled: ["xl", "xxl"] %>

<%# HTML attributes on the <select> tag %>
<%= form.select :status, statuses, {}, { class: "form-select", data: { action: "change->filter#apply" } } %>
<%#                                 ^options  ^html_attributes                                             %>
<%# NOTE: The empty {} for options is required when passing HTML attributes! %>

<%# Multiple select %>
<%= form.select :tag_ids, Tag.all.pluck(:name, :id), {}, { multiple: true } %>
```

### Option Groups

```erb
<%# Hash of group_name => options %>
<%= form.select :city, {
  "Europe" => [["Berlin", "BE"], ["Madrid", "MD"]],
  "North America" => [["Chicago", "CHI"], ["New York", "NY"]]
} %>
<%# Generates <optgroup label="Europe">...</optgroup> %>
```

### collection_select

For belongs_to associations. Queries a collection and extracts value/label.

```erb
<%= form.collection_select :author_id, Author.order(:name), :id, :name %>
<%#                        ^attribute  ^collection          ^value ^label %>

<%# With prompt %>
<%= form.collection_select :author_id, Author.order(:name), :id, :name,
    { prompt: "Select author" }, { class: "form-select" } %>
<%#  ^options                    ^html_attributes %>

<%# With selected and include_blank %>
<%= form.collection_select :category_id, Category.all, :id, :name,
    { include_blank: "None", selected: @article.category_id } %>
```

**Argument order matters:** `collection_select(attribute, collection, value_method, text_method, options = {}, html_options = {})`

The value method comes BEFORE the text method — opposite of how `[label, value]` pairs work in `select`.

### grouped_collection_select

For two-level grouped selects — e.g., cities grouped by country.

```erb
<%= form.grouped_collection_select :city_id,
    Country.order(:name),  # collection of groups
    :cities,               # method to get options for each group
    :name,                 # method for group label
    :id,                   # method for option value
    :name                  # method for option label
%>
```

Given:
```ruby
Country: { name: "USA", cities: [City{id: 1, name: "NYC"}, City{id: 2, name: "LA"}] }
Country: { name: "UK",  cities: [City{id: 3, name: "London"}] }
```

Generates:
```html
<select name="...[city_id]">
  <optgroup label="UK">
    <option value="3">London</option>
  </optgroup>
  <optgroup label="USA">
    <option value="1">NYC</option>
    <option value="2">LA</option>
  </optgroup>
</select>
```

### collection_radio_buttons

```erb
<%= form.collection_radio_buttons :city_id, City.all, :id, :name %>

<%# With custom rendering via block %>
<%= form.collection_radio_buttons :city_id, City.all, :id, :name do |b| %>
  <div class="radio-option">
    <%= b.radio_button class: "form-radio" %>
    <%= b.label class: "ml-2" %>
  </div>
<% end %>
```

### collection_checkboxes

For has_and_belongs_to_many or has_many :through:

```erb
<%= form.collection_checkboxes :interest_ids, Interest.all, :id, :name %>

<%# With custom block %>
<%= form.collection_checkboxes :tag_ids, Tag.all, :id, :name do |b| %>
  <label class="flex items-center gap-2">
    <%= b.check_box class: "form-checkbox" %>
    <%= b.text %>
  </label>
<% end %>
```

### time_zone_select

```erb
<%= form.time_zone_select :time_zone %>

<%# With priority zones %>
<%= form.time_zone_select :time_zone, ActiveSupport::TimeZone.us_zones, default: "Eastern Time (US & Canada)" %>
```

---

## Nested Attributes Patterns

### has_one Association

```ruby
# Model
class User < ApplicationRecord
  has_one :profile, dependent: :destroy
  accepts_nested_attributes_for :profile
end

# Controller
def new
  @user = User.new
  @user.build_profile  # build_<singular> for has_one
end

def user_params
  params.expect(user: [:name, :email, profile_attributes: [:id, :bio, :website]])
end
```

```erb
<%= form_with model: @user do |form| %>
  <%= form.text_field :name %>
  
  <%= form.fields_for :profile do |profile_form| %>
    <%= profile_form.textarea :bio %>
    <%= profile_form.url_field :website %>
  <% end %>
  
  <%= form.submit %>
<% end %>
```

### has_many Association

```ruby
# Model
class Person < ApplicationRecord
  has_many :addresses, inverse_of: :person, dependent: :destroy
  accepts_nested_attributes_for :addresses,
    allow_destroy: true,
    reject_if: :all_blank
end

# Controller
def new
  @person = Person.new
  2.times { @person.addresses.build }
end

def edit
  @person = Person.find(params[:id])
  @person.addresses.build if @person.addresses.empty?
end

def person_params
  params.expect(person: [
    :name,
    addresses_attributes: [[:id, :kind, :street, :city, :state, :zip, :_destroy]]
  ])
end
```

```erb
<%= form_with model: @person do |form| %>
  <%= form.text_field :name %>

  <%= form.fields_for :addresses do |af| %>
    <fieldset class="nested-address">
      <%= af.label :kind %>
      <%= af.select :kind, ["Home", "Work", "Other"] %>
      <%= af.label :street %>
      <%= af.text_field :street %>
      <%= af.label :city %>
      <%= af.text_field :city %>
      
      <%# Destroy checkbox — only for persisted records %>
      <% if af.object.persisted? %>
        <%= af.checkbox :_destroy %>
        <%= af.label :_destroy, "Remove this address" %>
      <% end %>
    </fieldset>
  <% end %>

  <%= form.submit %>
<% end %>
```

### Deeply Nested (has_many through has_many)

```ruby
# Models
class Survey < ApplicationRecord
  has_many :questions, inverse_of: :survey, dependent: :destroy
  accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: :all_blank
end

class Question < ApplicationRecord
  belongs_to :survey, inverse_of: :questions
  has_many :answers, inverse_of: :question, dependent: :destroy
  accepts_nested_attributes_for :answers, allow_destroy: true, reject_if: :all_blank
end

class Answer < ApplicationRecord
  belongs_to :question, inverse_of: :answers
end

# Controller
def new
  @survey = Survey.new
  question = @survey.questions.build
  question.answers.build
end

def survey_params
  params.expect(survey: [
    :title,
    questions_attributes: [[
      :id, :text, :_destroy,
      answers_attributes: [[:id, :text, :correct, :_destroy]]
    ]]
  ])
end
```

```erb
<%= form_with model: @survey do |form| %>
  <%= form.text_field :title %>

  <%= form.fields_for :questions do |qf| %>
    <div class="question">
      <%= qf.text_field :text, placeholder: "Question text" %>
      <%= qf.checkbox :_destroy %>
      <%= qf.label :_destroy, "Remove question" %>

      <%= qf.fields_for :answers do |af| %>
        <div class="answer">
          <%= af.text_field :text, placeholder: "Answer text" %>
          <%= af.checkbox :correct %>
          <%= af.label :correct, "Correct?" %>
          <%= af.checkbox :_destroy %>
          <%= af.label :_destroy, "Remove" %>
        </div>
      <% end %>
    </div>
  <% end %>

  <%= form.submit %>
<% end %>
```

### reject_if Options

```ruby
# Reject if ALL attributes are blank (most common)
accepts_nested_attributes_for :addresses, reject_if: :all_blank

# Reject with custom proc
accepts_nested_attributes_for :addresses, reject_if: ->(attrs) {
  attrs[:street].blank? && attrs[:city].blank?
}

# Reject with named method
accepts_nested_attributes_for :addresses, reject_if: :incomplete_address?

def incomplete_address?(attrs)
  attrs[:street].blank?
end
```

### Limiting Nested Records

```ruby
# Maximum number of nested records
accepts_nested_attributes_for :addresses, limit: 5

# Raises TooManyRecords if exceeded
```

### update_only for has_one

```ruby
# For has_one — update existing record instead of replacing
accepts_nested_attributes_for :profile, update_only: true
```

---

## File Uploads

### Basic Upload

```erb
<%= form_with model: @document do |form| %>
  <%= form.file_field :attachment %>
  <%= form.submit %>
<% end %>
```

`form_with` auto-sets `enctype="multipart/form-data"` when any `file_field` is present.

### Multiple Files

```erb
<%= form.file_field :images, multiple: true %>
```

Controller:
```ruby
def document_params
  params.expect(document: [:title, images: []])
end
```

### With Active Storage

```ruby
# Model
class User < ApplicationRecord
  has_one_attached :avatar
  has_many_attached :documents
end
```

```erb
<%= form.file_field :avatar %>
<%= form.file_field :documents, multiple: true %>
```

```ruby
# Strong params — Active Storage fields are just attribute names
params.expect(user: [:name, :avatar, documents: []])
```

### Direct Upload (Active Storage)

```erb
<%= form.file_field :avatar, direct_upload: true %>
```

Requires Active Storage JavaScript. Files upload directly to cloud storage, bypassing the Rails server.

### Accept Attribute

```erb
<%= form.file_field :avatar, accept: "image/png,image/jpeg,image/gif" %>
<%= form.file_field :document, accept: ".pdf,.doc,.docx" %>
```

---

## Custom Form Builders

### Basic Custom Builder

```ruby
# app/form_builders/tailwind_form_builder.rb
class TailwindFormBuilder < ActionView::Helpers::FormBuilder
  # Wrap text_field with label and error display
  def text_field(attribute, options = {})
    options[:class] = "#{options[:class]} border rounded px-3 py-2 w-full".strip
    field_wrapper(attribute) do
      label(attribute, class: "block text-sm font-medium mb-1") +
        super(attribute, options) +
        error_message(attribute)
    end
  end

  # Same for email_field, password_field, etc.
  %i[email_field password_field telephone_field url_field search_field].each do |method|
    define_method(method) do |attribute, options = {}|
      options[:class] = "#{options[:class]} border rounded px-3 py-2 w-full".strip
      field_wrapper(attribute) do
        label(attribute, class: "block text-sm font-medium mb-1") +
          super(attribute, options) +
          error_message(attribute)
      end
    end
  end

  def submit(value = nil, options = {})
    options[:class] = "#{options[:class]} bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700".strip
    super(value, options)
  end

  private

  def field_wrapper(attribute, &block)
    has_error = object&.errors&.[](attribute)&.any?
    css = "mb-4 #{'has-error' if has_error}"
    @template.content_tag(:div, class: css, &block)
  end

  def error_message(attribute)
    return "".html_safe unless object&.errors&.[](attribute)&.any?

    messages = object.errors[attribute].join(", ")
    @template.content_tag(:p, messages, class: "text-red-500 text-sm mt-1")
  end
end
```

### Using the Custom Builder

```erb
<%= form_with model: @user, builder: TailwindFormBuilder do |form| %>
  <%= form.text_field :name %>
  <%= form.email_field :email %>
  <%= form.submit %>
<% end %>
```

### Default Builder for All Forms

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def app_form_with(**options, &block)
    options[:builder] ||= TailwindFormBuilder
    form_with(**options, &block)
  end
end
```

### Builder with Error Summary

```ruby
class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def error_summary
    return "".html_safe unless object&.errors&.any?

    @template.content_tag(:div, class: "bg-red-50 border border-red-200 rounded p-4 mb-6") do
      @template.content_tag(:h3, "#{object.errors.count} error(s) prevented saving:", class: "font-bold text-red-800") +
        @template.content_tag(:ul, class: "list-disc pl-5 mt-2 text-red-700") do
          object.errors.full_messages.map { |msg|
            @template.content_tag(:li, msg)
          }.join.html_safe
        end
    end
  end
end
```

---

## Params Naming Conventions

### How Input Names Map to Params

| Input `name` attribute | `params` access |
|------------------------|-----------------|
| `name` | `params[:name]` |
| `person[name]` | `params[:person][:name]` |
| `person[address][city]` | `params[:person][:address][:city]` |
| `person[phone][]` | `params[:person][:phone]` → Array |
| `person[addresses][][street]` | `params[:person][:addresses]` → Array of Hashes |
| `person[addresses_attributes][0][street]` | `params[:person][:addresses_attributes]["0"][:street]` |

### Strong Parameters Patterns

```ruby
# Simple attributes
params.expect(article: [:title, :body, :published])

# With belongs_to (foreign key)
params.expect(article: [:title, :category_id, :author_id])

# With array values (multi-select, collection_checkboxes)
params.expect(article: [:title, tag_ids: []])

# With nested attributes (has_many)
params.expect(person: [
  :name,
  addresses_attributes: [[:id, :street, :city, :_destroy]]
])

# With nested attributes (has_one)
params.expect(user: [
  :name,
  profile_attributes: [:id, :bio, :website]
])

# With file uploads
params.expect(user: [:name, :avatar])           # has_one_attached
params.expect(user: [:name, documents: []])      # has_many_attached

# Complex combination
params.expect(article: [
  :title, :body, :category_id, :published,
  tag_ids: [],
  images: [],
  comments_attributes: [[:id, :body, :_destroy]]
])
```

### params.expect vs params.require.permit

Rails 8 prefers `params.expect` over `params.require(...).permit(...)`:

```ruby
# Rails 8 style (preferred)
params.expect(article: [:title, :body])

# Older style (still works)
params.require(:article).permit(:title, :body)
```

Key difference: `params.expect` with nested arrays uses double brackets `[[:id, :name]]` to indicate "array of hashes with these keys". Single brackets `[:id, :name]` means "single hash with these keys".

---

## Dynamic Nested Fields with Stimulus

### Stimulus Controller

```javascript
// app/javascript/controllers/nested_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container", "destroy"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime().toString()
    )
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".nested-fields")
    
    // If record exists in DB, mark for destruction
    const destroyInput = wrapper.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      wrapper.style.display = "none"
    } else {
      // New unsaved record — just remove from DOM
      wrapper.remove()
    }
  }
}
```

### Form Template

```erb
<%= form_with model: @person, data: { controller: "nested-form" } do |form| %>
  <%= form.text_field :name %>

  <%# Hidden template for new records %>
  <template data-nested-form-target="template">
    <%= form.fields_for :addresses, Address.new, child_index: "NEW_RECORD" do |af| %>
      <div class="nested-fields">
        <%= af.label :street %>
        <%= af.text_field :street %>
        <%= af.label :city %>
        <%= af.text_field :city %>
        <%= af.hidden_field :_destroy, value: "0" %>
        <button type="button" data-action="nested-form#remove">Remove</button>
      </div>
    <% end %>
  </template>

  <%# Container for existing + new records %>
  <div data-nested-form-target="container">
    <%= form.fields_for :addresses do |af| %>
      <div class="nested-fields">
        <%= af.label :street %>
        <%= af.text_field :street %>
        <%= af.label :city %>
        <%= af.text_field :city %>
        <%= af.hidden_field :_destroy, value: "0" %>
        <button type="button" data-action="nested-form#remove">Remove</button>
      </div>
    <% end %>
  </div>

  <button type="button" data-action="nested-form#add">Add Address</button>
  <%= form.submit %>
<% end %>
```

**Key detail:** `child_index: "NEW_RECORD"` in the template produces input names like `person[addresses_attributes][NEW_RECORD][street]`. The Stimulus controller replaces `NEW_RECORD` with a timestamp, ensuring unique indices for each dynamically added set of fields.

---

## Edge Cases and Gotchas

### 1. Checkbox Hidden Field

Every `checkbox` generates a hidden input with value "0" before the actual checkbox. This ensures unchecked boxes submit "0" instead of nothing.

```html
<input name="article[published]" type="hidden" value="0" autocomplete="off">
<input type="checkbox" value="1" name="article[published]" id="article_published">
```

To suppress the hidden field: `form.checkbox :published, include_hidden: false`

### 2. Select HTML Attributes Require Empty Options Hash

```erb
<%# WRONG — class goes into options, not html_attributes %>
<%= form.select :status, statuses, class: "form-select" %>

<%# RIGHT — empty options hash, then html_attributes %>
<%= form.select :status, statuses, {}, class: "form-select" %>
<%#                                ^^ empty options hash is required %>
```

This is the single most common `select` mistake. The signature is:
`select(attribute, choices, options = {}, html_options = {})`

### 3. fields_for Renders Nothing for Empty Associations

```erb
<%# This renders NOTHING if @person.addresses is empty %>
<%= form.fields_for :addresses do |af| %>
  ...
<% end %>
```

**Always build at least one child in the controller:**
```ruby
@person.addresses.build if @person.addresses.empty?
```

### 4. belongs_to Field Must Use Foreign Key

```erb
<%# WRONG %>
<%= form.collection_select :author, Author.all, :id, :name %>

<%# RIGHT — use the foreign key column %>
<%= form.collection_select :author_id, Author.all, :id, :name %>
```

### 5. Singular Resource Routing

`form_with model: @profile` won't work with singular resources unless you add a resolver:

```ruby
# config/routes.rb
resource :profile  # singular

# config/initializers/routing.rb (or in routes)
resolve("Profile") { [:profile] }
```

### 6. STI (Single Table Inheritance) Subclass Forms

```ruby
# If Animal is the resource but you have Dog < Animal
form_with model: @dog  # Tries to route to dogs_path, which doesn't exist!

# Fix: specify URL explicitly
form_with model: @dog, url: animal_path(@dog)

# Or: polymorphic route helper
form_with model: @dog, url: polymorphic_path(@dog, type: :animal)
```

### 7. Multi-parameter Date Attributes

`date_select` and `time_select` generate multiple `<select>` tags with names like:
- `person[birth_date(1i)]` (year)
- `person[birth_date(2i)]` (month)  
- `person[birth_date(3i)]` (day)

Active Record reassembles these automatically. Just permit the attribute name:
```ruby
params.expect(person: [:name, :birth_date])
```

### 8. Turbo and form_with

In Rails 7+ with Turbo, all forms submit via Turbo by default. To opt out:

```erb
<%= form_with model: @article, data: { turbo: false } do |form| %>
```

For Turbo Stream responses, your controller should respond to `turbo_stream` format:
```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to @article }
end
```

### 9. Array Params with Checkboxes Don't Work Well

Checkboxes with `[]` array names have issues because the hidden field and checkbox both submit values. Use `collection_checkboxes` instead of manual checkbox arrays.

### 10. form_with Defaults to POST

Unlike `form_tag` which also defaulted to POST, `form_with` with a model automatically selects POST (new) or PATCH (persisted). When using `url:` without a model, it defaults to POST. Always set `method: :get` explicitly for search/filter forms.

---

## Migration from form_for / form_tag

### form_for → form_with

```erb
<%# BEFORE (deprecated) %>
<%= form_for @article do |f| %>
  <%= f.text_field :title %>
<% end %>

<%# AFTER %>
<%= form_with model: @article do |form| %>
  <%= form.text_field :title %>
<% end %>
```

Key differences:
- `form_for @article` → `form_with model: @article`
- Behavior is identical; only syntax changes

### form_tag → form_with

```erb
<%# BEFORE (deprecated) %>
<%= form_tag search_path, method: :get do %>
  <%= text_field_tag :query %>
  <%= submit_tag "Search" %>
<% end %>

<%# AFTER %>
<%= form_with url: search_path, method: :get do |form| %>
  <%= form.search_field :query %>
  <%= form.submit "Search" %>
<% end %>
```

Key differences:
- `form_tag path` → `form_with url: path`
- `text_field_tag :name` → `form.text_field :name` (use the builder)
- `submit_tag` → `form.submit`
- `_tag` helpers → form builder methods

### _tag Helpers Still Exist

The `*_tag` helpers (e.g., `text_field_tag`, `hidden_field_tag`) still work and are useful **outside** a form builder context. Inside a `form_with` block, always use the form builder methods.

```erb
<%# Outside form_with — _tag helpers are fine %>
<%= hidden_field_tag :return_to, request.path %>

<%# Inside form_with — use the builder %>
<%= form_with model: @article do |form| %>
  <%= form.hidden_field :status, value: "draft" %>  <%# NOT hidden_field_tag %>
<% end %>
```

---

## Common Form Patterns

### Inline Error Display

```erb
<%= form_with model: @article do |form| %>
  <div class="field <%= 'has-error' if @article.errors[:title].any? %>">
    <%= form.label :title %>
    <%= form.text_field :title %>
    <% if @article.errors[:title].any? %>
      <span class="error"><%= @article.errors[:title].first %></span>
    <% end %>
  </div>
<% end %>
```

### Conditional Fields

```erb
<%= form_with model: @order do |form| %>
  <%= form.select :shipping_method, ["Standard", "Express", "Pickup"],
      data: { action: "change->order-form#toggleAddress" } %>
  
  <div data-order-form-target="addressFields">
    <%= form.text_field :address %>
    <%= form.text_field :city %>
  </div>
<% end %>
```

### Form with Multiple Submit Buttons

```erb
<%= form_with model: @article do |form| %>
  <%= form.text_field :title %>
  <%= form.textarea :body %>
  
  <%= form.submit "Save Draft", name: "commit", value: "draft" %>
  <%= form.submit "Publish", name: "commit", value: "publish" %>
<% end %>
```

Controller:
```ruby
def create
  @article = Article.new(article_params)
  @article.published = (params[:commit] == "publish")
  @article.save
end
```

### Delete Button as Form

```erb
<%= form_with url: article_path(@article), method: :delete do |form| %>
  <%= form.submit "Delete", data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<%# Or use button_to shorthand %>
<%= button_to "Delete", article_path(@article), method: :delete,
    data: { turbo_confirm: "Are you sure?" } %>
```
