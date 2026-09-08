# Testing Validations, Performance, and Miscellaneous Patterns

Test patterns, performance considerations, and additional validation recipes.

## Testing Validations

### Pattern: In-memory validation tests

```ruby
class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:valid_user)  # fixture
  end

  test "valid fixture" do
    assert @user.valid?
  end

  test "requires email" do
    @user.email = nil
    refute @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    other = users(:other_user)
    @user.email = other.email
    refute @user.valid?
    assert_includes @user.errors[:email], "has already been taken"
  end

  test "rejects invalid email format" do
    @user.email = "not-an-email"
    refute @user.valid?
    assert_includes @user.errors[:email], "is not a valid email"
  end

  test "validates numericality of age" do
    @user.age = "abc"
    refute @user.valid?
    assert_includes @user.errors[:age], "is not a number"
  end

  test "rejects negative price" do
    product = Product.new(price: -1)
    refute product.valid?
    assert_includes product.errors[:price], "must be greater than 0"
  end
end
```

### Pattern: Test conditional validations

```ruby
test "requires card number only when paying by card" do
  order = Order.new(payment_type: "cash")
  order.valid?
  assert_empty order.errors[:card_number]

  order.payment_type = "card"
  order.valid?
  assert_includes order.errors[:card_number], "can't be blank"
end
```

### Pattern: Test custom validators

```ruby
test "rejects end date before start date" do
  event = Event.new(start_date: Date.tomorrow, end_date: Date.today)
  refute event.valid?
  assert_includes event.errors[:end_date], "must be after start date"
end
```

### Pattern: Test DB constraints survive

```ruby
test "DB constraint prevents duplicate email" do
  User.create!(email: "dup@test.com", name: "First")
  assert_raises ActiveRecord::RecordNotUnique do
    User.connection.execute(
      "INSERT INTO users (email, name, created_at, updated_at) VALUES ('dup@test.com', 'Second', NOW(), NOW())"
    )
  end
end
```

### Pattern: Test normalizations

```ruby
test "normalizes email on assignment" do
  user = User.new(email: "  FOO@BAR.COM  ")
  assert_equal "foo@bar.com", user.email
end

test "normalizes email in queries" do
  user = users(:valid_user)  # email: "alice@example.com"
  assert_equal user, User.find_by(email: "  ALICE@EXAMPLE.COM  ")
end
```

---

## Performance Considerations

### Uniqueness queries

Every `uniqueness` validation fires a `SELECT` query. On high-traffic models:

```ruby
# This generates N+1 queries if validating many records:
records.each { |r| r.valid? }

# Consider batch validation or DB-level only for bulk imports
```

### validates_associated cost

```ruby
# If library has 1000 books, this calls valid? on ALL of them:
validates_associated :books

# Consider limiting or skipping for large collections:
validates_associated :books, if: -> { books.size < 100 }
```

### Conditional validation performance

```ruby
# If the :if method is expensive, it runs on every validation:
validates :extra_field, presence: true, if: :expensive_api_check?

# Cache the result:
validates :extra_field, presence: true, if: :needs_extra_field?

def needs_extra_field?
  @_needs_extra_field ||= expensive_api_check?
end
```

### Normalization on every assignment

Normalizations run on every attribute write. Keep them cheap:

```ruby
# Good — fast string operations:
normalizes :email, with: ->(e) { e.strip.downcase }

# Bad — expensive operation on every assignment:
normalizes :address, with: ->(a) { GeocodingService.normalize(a) }
# Move this to a before_validation callback instead
```

---

## Miscellaneous Patterns

### Validating array/JSON columns (PostgreSQL)

```ruby
class Product < ApplicationRecord
  validate :valid_tags

  private

  def valid_tags
    return if tags.blank?
    unless tags.is_a?(Array) && tags.all? { |t| t.is_a?(String) && t.length <= 50 }
      errors.add(:tags, "must be an array of strings (max 50 chars each)")
    end
    if tags.length > 10
      errors.add(:tags, "cannot have more than 10 tags")
    end
  end
end
```

### Validating nested attributes

```ruby
class Order < ApplicationRecord
  has_many :line_items
  accepts_nested_attributes_for :line_items, reject_if: :all_blank, allow_destroy: true
  validates_associated :line_items
  validate :at_least_one_line_item

  private

  def at_least_one_line_item
    if line_items.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "must have at least one line item")
    end
  end
end
```

### Validation outside Active Record

```ruby
class ContactForm
  include ActiveModel::Validations

  attr_accessor :name, :email, :message

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { minimum: 10 }
end

form = ContactForm.new
form.name = "Alice"
form.valid?  # => false (email and message missing)
form.errors.full_messages  # ["Email can't be blank", ...]
```

### Listing validators on a model

```ruby
User.validators                    # All validators
User.validators_on(:email)        # Validators for :email
User.validators_on(:email).map(&:class)  # [PresenceValidator, UniquenessValidator, ...]
```
