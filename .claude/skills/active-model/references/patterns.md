# Advanced Patterns

## Form Object with Nested Attributes

```ruby
class EventRegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :event_name, :string
  attribute :event_date, :date
  attribute :organizer_name, :string
  attribute :organizer_email, :string
  attribute :max_attendees, :integer, default: 100

  validates :event_name, :event_date, :organizer_name, :organizer_email, presence: true
  validates :organizer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :max_attendees, numericality: { greater_than: 0 }
  validate :event_date_in_future

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      organizer = User.find_or_create_by!(email: organizer_email) do |u|
        u.name = organizer_name
      end
      Event.create!(
        name: event_name,
        date: event_date,
        organizer:,
        max_attendees:
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def event_date_in_future
    return if event_date.blank?
    errors.add(:event_date, "must be in the future") if event_date <= Date.current
  end
end
```

## Decorator/Presenter with Validation

```ruby
class PublishableArticle
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :article

  attribute :publish_date, :datetime
  attribute :featured, :boolean, default: false
  attribute :seo_title, :string
  attribute :seo_description, :string

  validates :publish_date, presence: true
  validates :seo_title, presence: true, length: { maximum: 60 }
  validates :seo_description, presence: true, length: { maximum: 160 }
  validate :article_ready_to_publish

  def initialize(article, **attrs)
    @article = article
    super(**attrs)
  end

  def publish!
    return false unless valid?

    article.update!(
      published_at: publish_date,
      featured:,
      seo_title:,
      seo_description:,
      status: :published
    )
    true
  end

  private

  def article_ready_to_publish
    errors.add(:base, "Article body is empty") if article.body.blank?
    errors.add(:base, "Article needs a title") if article.title.blank?
  end
end
```

## Wizard/Multi-Step Form

```ruby
class OnboardingForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :step, :integer, default: 1

  # Step 1
  attribute :name, :string
  attribute :email, :string

  # Step 2
  attribute :company_name, :string
  attribute :role, :string

  # Step 3
  attribute :plan, :string
  attribute :billing_email, :string

  validates :name, :email, presence: true, if: -> { step >= 1 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { step >= 1 && email.present? }
  validates :company_name, :role, presence: true, if: -> { step >= 2 }
  validates :plan, presence: true, inclusion: { in: %w[starter growth enterprise] }, if: -> { step >= 3 }
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { step >= 3 && billing_email.present? }

  def valid_step?
    valid?
  end

  def next_step
    self.step += 1 if valid_step?
  end

  def final_step?
    step == 3
  end

  def complete!
    self.step = 3
    return false unless valid?

    ActiveRecord::Base.transaction do
      company = Company.create!(name: company_name)
      user = company.users.create!(name:, email:, role:)
      company.subscriptions.create!(plan:, billing_email: billing_email || email)
    end
    true
  end
end
```

## Service Object with Active Model Validation

```ruby
class TransferFunds
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :from_account_id, :integer
  attribute :to_account_id, :integer
  attribute :amount, :decimal
  attribute :memo, :string

  validates :from_account_id, :to_account_id, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validate :accounts_are_different
  validate :sufficient_balance

  def execute
    return failure unless valid?

    ActiveRecord::Base.transaction do
      from_account.lock!
      to_account.lock!

      from_account.decrement!(:balance, amount)
      to_account.increment!(:balance, amount)

      Transfer.create!(
        from_account:, to_account:,
        amount:, memo:
      )
    end
    success
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    failure
  end

  private

  def from_account = @from_account ||= Account.find_by(id: from_account_id)
  def to_account = @to_account ||= Account.find_by(id: to_account_id)

  def accounts_are_different
    return if from_account_id != to_account_id
    errors.add(:to_account_id, "must be different from source")
  end

  def sufficient_balance
    return unless from_account && amount
    errors.add(:amount, "exceeds available balance") if from_account.balance < amount
  end

  def success = OpenStruct.new(success?: true, errors: [])
  def failure = OpenStruct.new(success?: false, errors: errors.full_messages)
end
```

## Lint Tests

Use `ActiveModel::Lint::Tests` to verify your object is fully API-compliant:

```ruby
require "test_helper"

class ContactFormLintTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = ContactForm.new
  end
end
```

This runs compliance checks for `to_model`, `to_key`, `to_param`, `to_partial_path`, `persisted?`, and `model_name`.

## Edge Cases & Gotchas

### 1. `form_with` Requires `url:`

Active Model objects don't have routing. You must always pass `url:`:

```erb
<%# WRONG — will error or guess wrong route %>
<%= form_with model: @contact_form do |f| %>

<%# CORRECT %>
<%= form_with model: @contact_form, url: contact_forms_path do |f| %>
```

### 2. `persisted?` Defaults to `false`

Active Model objects return `false` from `persisted?` by default. This affects:
- `to_key` returns `nil`
- `to_param` returns `nil`
- `form_with` will use POST (not PATCH)

Override if needed:

```ruby
def persisted?
  id.present?
end
```

### 3. Attributes Requires Explicit `attributes` for Serialization

If you use both `ActiveModel::Attributes` and `ActiveModel::Serialization`, the `attribute` macro defines attributes for casting, but you still need an `attributes` method for serialization:

```ruby
class Thing
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON

  attribute :name, :string
  attribute :count, :integer

  # This is needed for serializable_hash / as_json / to_json
  def attributes
    { "name" => name, "count" => count }
  end
end
```

### 4. Callbacks Use `extend`, Not `include`

```ruby
# WRONG
class Foo
  include ActiveModel::Callbacks  # NoMethodError on define_model_callbacks
end

# CORRECT
class Foo
  extend ActiveModel::Callbacks
end
```

### 5. Dirty Tracking with Attributes

When using `ActiveModel::Attributes` + `ActiveModel::Dirty` together, you get automatic tracking without manual `_will_change!` calls. But you must include `Dirty` after `Attributes`:

```ruby
class Config
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty  # After Attributes

  attribute :theme, :string
end
```

### 6. Strong Parameters Integration

`assign_attributes` checks for `permitted?` on the hash. If you pass raw `params`, you'll get `ActiveModel::ForbiddenAttributesError`:

```ruby
# WRONG
form.assign_attributes(params[:contact_form])

# CORRECT
form.assign_attributes(params.require(:contact_form).permit(:name, :email))
```

### 7. `validates_associated` Doesn't Work

`validates_associated` is an Active Record validator. For form objects wrapping other models, validate manually:

```ruby
validate :nested_records_valid

def nested_records_valid
  items.each_with_index do |item, i|
    next if item.valid?
    item.errors.each do |error|
      errors.add(:base, "Item #{i + 1}: #{error.full_message}")
    end
  end
end
```

### 8. Boolean Casting Gotcha

`ActiveModel::Attributes` casts booleans aggressively. `"0"`, `"false"`, `"f"`, `"no"`, `"off"`, and `""` all become `false`. `"1"`, `"true"`, `"t"`, `"yes"`, `"on"` become `true`. Any other string becomes `true`.

```ruby
attribute :active, :boolean
# "banana" => true  (careful!)
# "" => false
# nil => nil
# 0 => false
# 1 => true
```

### 9. Initialization Order Matters

With `ActiveModel::Model`, attributes are assigned in hash order during `new`. If you have dependencies between attributes, handle them in a method, not in the initializer:

```ruby
# FRAGILE — depends on hash key ordering
class Foo
  include ActiveModel::Model
  attr_accessor :start_date, :duration, :end_date

  def initialize(attrs = {})
    super
    self.end_date = start_date + duration.days if start_date && duration
  end
end

# BETTER — compute on demand
class Foo
  include ActiveModel::Model
  attr_accessor :start_date, :duration

  def end_date
    start_date + duration.days if start_date && duration
  end
end
```
