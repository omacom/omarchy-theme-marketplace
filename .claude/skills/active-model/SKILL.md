---
name: active-model
description: Build plain Ruby objects that integrate with Rails forms, validations, serialization, and Action Pack — without a database. Use when building form objects, search forms, API wrappers, configuration objects, virtual models, or any PORO that needs model-like behavior. Triggers on "active model", "form object", "plain Ruby object", "non-database model", "ActiveModel", "PORO", "service object validation", "virtual model", "tableless model", "search form", "ActiveModel::API", "ActiveModel::Model".
allowed-tools: Read, Grep, Glob, Write, Edit
---

# Active Model Expert

Build model-like Ruby classes that work with Rails forms, validations, and serialization — without touching a database.

## Core Decision: Active Model vs Active Record

**Use Active Model when:**
- No database table backs the object
- Form objects that aggregate multiple models
- Search/filter forms
- API request/response wrappers
- Configuration or settings objects
- Contact forms, invite forms, onboarding wizards
- Decorators or presenters needing validation
- Service objects that need validation + error messages

**Use Active Record when:**
- Data must persist in a database
- You need associations, scopes, or query interface
- You need migrations and schema management

**The #1 agent mistake:** Reaching for Active Record (or raw POROs with hand-rolled validation) when Active Model gives you everything Rails forms and controllers expect — for free.

## Module Hierarchy

Understanding which module to include is critical:

| Module | What You Get | When To Use |
|--------|-------------|-------------|
| `ActiveModel::Model` | API + future extensions | **Default choice** — use this |
| `ActiveModel::API` | Validations, Naming, Conversion, Translation, AttributeAssignment | Lightweight alternative to Model |
| `ActiveModel::Attributes` | Typed attributes with casting + defaults | Need type coercion (dates, booleans, integers) |
| `ActiveModel::Validations` | Just validations | Adding validation to any object |
| `ActiveModel::Callbacks` | Lifecycle hooks (before/after/around) | Need callback chains |
| `ActiveModel::Dirty` | Change tracking | Track attribute modifications |
| `ActiveModel::Serialization` | `serializable_hash` | Need hash/JSON output |
| `ActiveModel::SecurePassword` | bcrypt password handling | Password without Active Record |

**Key insight:** `ActiveModel::Model` includes `ActiveModel::API`, which bundles Validations, Naming, Conversion, Translation, and AttributeAssignment. Start with `Model` and add other modules as needed.

## Instructions

### Step 1: Choose the Right Base

**For most form objects and virtual models — use `ActiveModel::Model`:**

```ruby
class ContactForm
  include ActiveModel::Model

  attr_accessor :name, :email, :message

  validates :name, :email, :message, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def submit
    return false unless valid?
    ContactMailer.new_message(name:, email:, message:).deliver_later
    true
  end
end
```

This works with `form_with`, `render`, and all Action View helpers immediately.

**When you need typed attributes — add `ActiveModel::Attributes`:**

```ruby
class SearchForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string
  attribute :min_price, :decimal
  attribute :max_price, :decimal
  attribute :available_only, :boolean, default: false
  attribute :created_after, :date

  validates :query, length: { minimum: 2 }, allow_blank: true

  def results
    scope = Product.all
    scope = scope.where("name ILIKE ?", "%#{query}%") if query.present?
    scope = scope.where("price >= ?", min_price) if min_price.present?
    scope = scope.where("price <= ?", max_price) if max_price.present?
    scope = scope.where(available: true) if available_only
    scope = scope.where("created_at >= ?", created_after) if created_after.present?
    scope
  end
end
```

`Attributes` gives you automatic type casting — string `"true"` becomes boolean `true`, string `"2024-01-15"` becomes a `Date`.

### Step 2: Wire Into Controllers

Active Model objects work exactly like Active Record in controllers:

```ruby
class ContactFormsController < ApplicationController
  def new
    @contact_form = ContactForm.new
  end

  def create
    @contact_form = ContactForm.new(contact_form_params)
    if @contact_form.submit
      redirect_to root_path, notice: "Message sent!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_form_params
    params.require(:contact_form).permit(:name, :email, :message)
  end
end
```

### Step 3: Use with Forms

```erb
<%= form_with model: @contact_form, url: contact_forms_path do |f| %>
  <% if @contact_form.errors.any? %>
    <div id="errors">
      <% @contact_form.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <%= f.text_field :name %>
  <%= f.email_field :email %>
  <%= f.text_area :message %>
  <%= f.submit "Send" %>
<% end %>
```

**Key:** You must provide `url:` in `form_with` since Active Model objects aren't routable by default (no `persisted?` returning true, no `id`).

### Step 4: Add Modules As Needed

Only include what you actually use. Don't cargo-cult every module.

**Callbacks** — when you need lifecycle hooks:

```ruby
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  extend ActiveModel::Callbacks

  define_model_callbacks :save

  attribute :email, :string
  attribute :name, :string
  attribute :company_name, :string

  before_save :normalize_email
  after_save :send_welcome_email

  def save
    return false unless valid?
    run_callbacks(:save) do
      create_records!
    end
    true
  end

  private

  def normalize_email
    self.email = email.downcase.strip
  end

  def send_welcome_email
    WelcomeMailer.registration(@user).deliver_later
  end

  def create_records!
    @company = Company.create!(name: company_name)
    @user = @company.users.create!(email:, name:)
  end
end
```

**Important:** `extend` (not `include`) for Callbacks. And you must call `run_callbacks(:event) { ... }` yourself — Active Model doesn't auto-invoke them.

**Dirty tracking** — when you need change detection:

```ruby
class Settings
  include ActiveModel::Model
  include ActiveModel::Dirty

  define_attribute_methods :theme, :language

  def theme
    @theme
  end

  def theme=(value)
    theme_will_change! unless value == @theme
    @theme = value
  end

  def language
    @language
  end

  def language=(value)
    language_will_change! unless value == @language
    @language = value
  end

  def save
    changes_applied
  end

  def reload!
    clear_changes_information
  end
end
```

**Serialization** — for JSON APIs:

```ruby
class ApiResponse
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  attr_accessor :status, :data, :timestamp

  def attributes
    { "status" => nil, "data" => nil, "timestamp" => nil }
  end
end

response = ApiResponse.new(status: "ok", data: { count: 42 }, timestamp: Time.current)
response.as_json  # => {"status"=>"ok", "data"=>{"count"=>42}, "timestamp"=>"2024-..."}
response.to_json  # => '{"status":"ok",...}'
```

**SecurePassword** — password handling without Active Record:

```ruby
class SessionForm
  include ActiveModel::Model
  include ActiveModel::SecurePassword

  has_secure_password

  attr_accessor :password_digest

  def authenticate_user(email, password)
    user = User.find_by(email:)
    user&.authenticate(password)
  end
end
```

Requires the `bcrypt` gem. Provides `password`, `password_confirmation`, and `authenticate` methods.

### Step 5: Naming and Translation

`ActiveModel::Model` includes Naming and Translation automatically.

**Customize model name** (useful for namespaced classes):

```ruby
module Admin
  class InviteForm
    include ActiveModel::Model

    def self.model_name
      ActiveModel::Name.new(self, nil, "InviteForm")
    end
  end
end

# Without override: form params would be admin_invite_form[email]
# With override:    form params are invite_form[email]
```

**I18n for attribute names:**

```yaml
# config/locales/en.yml
en:
  activemodel:
    attributes:
      contact_form:
        name: "Full Name"
        email: "Email Address"
    errors:
      models:
        contact_form:
          attributes:
            email:
              invalid: "doesn't look right"
```

### Step 6: Test Active Model Objects

```ruby
require "test_helper"

class ContactFormTest < ActiveSupport::TestCase
  test "valid with all attributes" do
    form = ContactForm.new(name: "Jane", email: "jane@example.com", message: "Hello")
    assert form.valid?
  end

  test "invalid without name" do
    form = ContactForm.new(email: "jane@example.com", message: "Hello")
    refute form.valid?
    assert_includes form.errors[:name], "can't be blank"
  end

  test "invalid with bad email" do
    form = ContactForm.new(name: "Jane", email: "not-an-email", message: "Hello")
    refute form.valid?
    assert_includes form.errors[:email], "is invalid"
  end

  test "#submit delivers email when valid" do
    form = ContactForm.new(name: "Jane", email: "jane@example.com", message: "Hello")
    assert_enqueued_emails 1 do
      assert form.submit
    end
  end

  test "#submit returns false when invalid" do
    form = ContactForm.new
    refute form.submit
  end
end
```

**Lint tests** — verify API compliance:

```ruby
class ContactFormLintTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = ContactForm.new
  end
end
```

## Common Patterns

### Form Object (Multi-Model)

```ruby
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :user_email, :string
  attribute :user_name, :string
  attribute :company_name, :string
  attribute :plan, :string, default: "free"

  validates :user_email, :user_name, :company_name, presence: true
  validates :user_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :plan, inclusion: { in: %w[free pro enterprise] }

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      company = Company.create!(name: company_name)
      company.users.create!(email: user_email, name: user_name)
      company.subscriptions.create!(plan:)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end
end
```

### Search/Filter Form

```ruby
class OrderSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :string
  attribute :customer_name, :string
  attribute :date_from, :date
  attribute :date_to, :date
  attribute :min_total, :decimal
  attribute :sort_by, :string, default: "created_at"
  attribute :sort_direction, :string, default: "desc"

  def results
    scope = Order.includes(:customer)
    scope = scope.where(status:) if status.present?
    scope = scope.joins(:customer).where("customers.name ILIKE ?", "%#{customer_name}%") if customer_name.present?
    scope = scope.where("orders.created_at >= ?", date_from) if date_from.present?
    scope = scope.where("orders.created_at <= ?", date_to) if date_to.present?
    scope = scope.where("orders.total >= ?", min_total) if min_total.present?
    scope = scope.order(sort_by => sort_direction)
    scope
  end
end
```

### Configuration Object

```ruby
class NotificationPreferences
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON

  attribute :email_enabled, :boolean, default: true
  attribute :sms_enabled, :boolean, default: false
  attribute :digest_frequency, :string, default: "daily"
  attribute :quiet_hours_start, :integer, default: 22
  attribute :quiet_hours_end, :integer, default: 8

  validates :digest_frequency, inclusion: { in: %w[realtime hourly daily weekly] }
  validates :quiet_hours_start, :quiet_hours_end,
            numericality: { in: 0..23 }

  def attributes
    {
      "email_enabled" => nil,
      "sms_enabled" => nil,
      "digest_frequency" => nil,
      "quiet_hours_start" => nil,
      "quiet_hours_end" => nil
    }
  end

  def quiet_now?
    hour = Time.current.hour
    if quiet_hours_start > quiet_hours_end
      hour >= quiet_hours_start || hour < quiet_hours_end
    else
      hour >= quiet_hours_start && hour < quiet_hours_end
    end
  end
end
```

## Anti-Patterns

1. **Using Active Record for non-persisted objects** — If there's no table, don't subclass `ApplicationRecord`
2. **Hand-rolling validations** — Don't write `raise "Name required" if name.blank?` when `validates :name, presence: true` exists
3. **Skipping `ActiveModel::Model`** — Don't manually implement `initialize(attrs={})` with hash iteration; `Model` does it
4. **Including everything** — Only include modules you use; `Model` is enough for most cases
5. **Forgetting `url:` in `form_with`** — Active Model objects don't auto-resolve routes
6. **Using `extend` where `include` is needed** — Callbacks use `extend`; everything else uses `include`
7. **Not wrapping multi-model saves in transactions** — Form objects that create multiple records need `ActiveRecord::Base.transaction`
8. **Reimplementing `assign_attributes`** — `ActiveModel::Model` already gives you attribute assignment from a hash via the initializer

## Reference

For detailed patterns, edge cases, and advanced usage, see the `references/` directory:
- `references/api-and-attributes.md` — Model vs API, typed attributes, naming, translation, conversion
- `references/validations-and-callbacks.md` — All validators, custom validators, callbacks, error handling
- `references/dirty-tracking.md` — Manual and automatic change tracking
- `references/serialization.md` — serializable_hash, JSON serialization
- `references/patterns.md` — Form objects, wizards, service objects, lint tests, edge cases
