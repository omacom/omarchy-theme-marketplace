# Validations & Callbacks

## ActiveModel::Validations

Everything from Active Record validations works here. Full list of built-in validators:

```ruby
class Payment
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :amount, :decimal
  attribute :currency, :string
  attribute :card_number, :string
  attribute :email, :string
  attribute :terms_accepted, :boolean

  # Presence
  validates :amount, :currency, presence: true

  # Numericality
  validates :amount, numericality: { greater_than: 0, less_than_or_equal_to: 999_999 }

  # Inclusion
  validates :currency, inclusion: { in: %w[usd eur gbp], message: "%{value} is not supported" }

  # Format
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Length
  validates :card_number, length: { is: 16 }

  # Acceptance (for checkboxes)
  validates :terms_accepted, acceptance: true

  # Custom validation method
  validate :amount_within_daily_limit

  private

  def amount_within_daily_limit
    return unless amount.present? && amount > 10_000
    errors.add(:amount, "exceeds daily limit of $10,000")
  end
end
```

## Conditional Validations

```ruby
class Order
  include ActiveModel::Model

  attr_accessor :payment_type, :card_number, :po_number

  validates :card_number, presence: true, if: -> { payment_type == "credit_card" }
  validates :po_number, presence: true, if: :purchase_order?

  private

  def purchase_order?
    payment_type == "purchase_order"
  end
end
```

## Validation Contexts

```ruby
class User
  include ActiveModel::Model

  attr_accessor :name, :email, :admin_notes

  validates :name, :email, presence: true
  validates :admin_notes, presence: true, on: :admin_review

  def valid_for_admin_review?
    valid?(:admin_review)
  end
end

user = User.new(name: "Jane", email: "jane@example.com")
user.valid?                # => true (default context)
user.valid?(:admin_review) # => false (admin_notes missing)
```

## Strict Validations (raise instead of adding errors)

```ruby
class ApiKey
  include ActiveModel::Model

  attr_accessor :token, :scope

  validates! :token, presence: true  # Raises ActiveModel::StrictValidationFailed
  validates :scope, presence: true   # Adds to errors normally
end
```

## Custom Validators

```ruby
class EmailDomainValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    domain = value.split("@").last
    unless options[:allowed_domains].include?(domain)
      record.errors.add(attribute, "must be from an allowed domain")
    end
  end
end

class Employee
  include ActiveModel::Model
  attr_accessor :email

  validates :email, email_domain: { allowed_domains: ["company.com", "subsidiary.com"] }
end
```

## ActiveModel::Callbacks

**Key differences from Active Record callbacks:**

1. Use `extend` (not `include`)
2. You must call `run_callbacks(:event) { ... }` yourself
3. Method names can't end with `!`, `?`, or `=`

```ruby
class Processor
  include ActiveModel::Model
  extend ActiveModel::Callbacks

  define_model_callbacks :process
  define_model_callbacks :validate, only: [:before, :after]  # Skip :around

  before_process :log_start
  after_process :log_end
  around_process :measure_time

  def process
    run_callbacks(:process) do
      # actual work here
      do_the_thing
    end
  end

  private

  def log_start
    Rails.logger.info "Starting process..."
  end

  def log_end
    Rails.logger.info "Process complete"
  end

  def measure_time
    start = Time.current
    yield  # MUST yield in around callbacks
    Rails.logger.info "Took #{Time.current - start}s"
  end
end
```

## Aborting Callbacks

```ruby
before_process :check_preconditions

def check_preconditions
  throw :abort unless ready?
end
```

When `:abort` is thrown, the callback chain stops and the block in `run_callbacks` is not executed.

## Class-based Callbacks

```ruby
class AuditLogger
  def self.before_process(obj)
    AuditLog.record(action: "process_start", subject: obj.class.name)
  end
end

class Processor
  extend ActiveModel::Callbacks
  define_model_callbacks :process
  before_process AuditLogger
end
```

## Error Handling Patterns

Active Model errors work the same as Active Record:

```ruby
form = ContactForm.new
form.valid?

form.errors.any?              # => true
form.errors.count             # => 3
form.errors[:name]            # => ["can't be blank"]
form.errors.full_messages     # => ["Name can't be blank", ...]
form.errors.added?(:name, :blank) # => true

# Add errors manually
form.errors.add(:base, "Something went wrong")
form.errors.add(:email, :taken, value: "test@example.com")

# Clear errors
form.errors.clear

# Iterate
form.errors.each do |error|
  puts "#{error.attribute}: #{error.message}"
end

# Group by attribute
form.errors.group_by_attribute
# => { name: [...], email: [...] }
```
