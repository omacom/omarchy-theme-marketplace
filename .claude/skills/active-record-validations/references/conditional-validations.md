# Conditional Validations and Multi-Step Forms

Patterns for conditional validation, context-based validation, and multi-step form flows.

## Symbol (method name) — preferred for named logic

```ruby
class Order < ApplicationRecord
  validates :shipping_address, presence: true, if: :physical_product?
  validates :download_url, presence: true, unless: :physical_product?

  private

  def physical_product?
    product_type == "physical"
  end
end
```

## Proc/Lambda — for simple one-liners

```ruby
validates :company, presence: true, if: -> { account_type == "business" }
validates :parent_email, presence: true, if: -> { age.present? && age < 18 }
```

**Rule of thumb:** If the lambda has `&&`, `||`, or is longer than ~40 chars, extract to a method.

## Array of conditions

```ruby
# ALL conditions must be true for validation to run
validates :bio, presence: true,
  if: [:profile_complete?, :public_profile?]

# Mix symbols and lambdas
validates :vat_number, presence: true,
  if: [:business_account?, -> { country.in?(%w[DE FR IT]) }]
```

## with_options grouping

```ruby
class User < ApplicationRecord
  with_options if: :admin? do
    validates :permissions, presence: true
    validates :security_clearance, numericality: { greater_than: 0 }
    validates :admin_notes, length: { maximum: 5000 }
  end

  with_options unless: :admin? do
    validates :terms_accepted, acceptance: true
  end
end
```

## :on context for multi-step flows

```ruby
class Registration < ApplicationRecord
  # Step 1: Basic info
  validates :email, presence: true  # always (no :on)
  validates :password, presence: true, on: :create

  # Step 2: Profile
  validates :name, presence: true, on: :profile_step
  validates :bio, length: { maximum: 500 }, on: :profile_step

  # Step 3: Payment
  validates :card_number, presence: true, on: :payment_step
  validates :billing_address, presence: true, on: :payment_step
end

# Controller:
def update_profile
  if @registration.save(context: :profile_step)
    redirect_to payment_step_path
  else
    render :profile_step
  end
end
```

---

## Multi-Step Form Validations

### Custom context approach

```ruby
class Application < ApplicationRecord
  # Always validated:
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Step 1: Personal info
  validates :first_name, presence: true, on: :personal_info
  validates :last_name, presence: true, on: :personal_info
  validates :date_of_birth, presence: true, on: :personal_info

  # Step 2: Address
  validates :street, presence: true, on: :address
  validates :city, presence: true, on: :address
  validates :zip_code, presence: true, on: :address

  # Step 3: Documents
  validates :id_document, presence: true, on: :documents
  validates :proof_of_address, presence: true, on: :documents
end
```

```ruby
# Controller:
class ApplicationsController < ApplicationController
  def update_step
    context = params[:step].to_sym
    if @application.save(context: context)
      redirect_to next_step_path
    else
      render current_step_template, status: :unprocessable_entity
    end
  end
end
```

**Note:** When triggered with a custom context, validations with `:on` matching that context run, PLUS all validations without any `:on` option. So the `email` validation above runs on every step.
