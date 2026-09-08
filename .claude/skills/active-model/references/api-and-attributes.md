# API, Attributes & Core Modules

## ActiveModel::API vs ActiveModel::Model

Both provide form/controller integration. The difference:

- **`ActiveModel::API`** — The core interface. Includes: AttributeAssignment, Conversion, Naming, Translation, Validations.
- **`ActiveModel::Model`** — Includes `API` plus is designed for future Rails extensions. **Always prefer `Model` over `API`** unless you have a specific reason not to.

```ruby
# These are functionally equivalent today, but Model is future-proof:
class Foo
  include ActiveModel::API  # Just the basics
end

class Bar
  include ActiveModel::Model  # Basics + future extensions
end
```

Both support:
- Hash-based initialization: `Foo.new(name: "Jane")`
- `form_with model: @foo`
- `render @foo` (partial rendering)
- `valid?`, `errors`, all validation helpers
- `model_name`, `to_model`, `to_key`, `to_param`, `to_partial_path`

## ActiveModel::Attributes

Provides typed attributes with automatic casting and defaults. This is one of the most useful modules for form objects.

**Supported built-in types:**
- `:string` — casts to String
- `:integer` — casts to Integer
- `:float` — casts to Float
- `:decimal` — casts to BigDecimal
- `:boolean` — casts to true/false (handles `"1"`, `"true"`, `"yes"`, `0`, `"false"`, `"no"`, etc.)
- `:date` — casts to Date
- `:datetime` — casts to DateTime/Time
- `:time` — casts to Time

```ruby
class ImportJob
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :file_path, :string
  attribute :skip_header, :boolean, default: true
  attribute :delimiter, :string, default: ","
  attribute :batch_size, :integer, default: 1000
  attribute :started_at, :datetime
end

job = ImportJob.new(skip_header: "0", batch_size: "500")
job.skip_header   # => false (cast from "0")
job.batch_size     # => 500 (cast from "500")
job.delimiter      # => "," (default)
```

**`attribute_names` and `attributes` methods:**

```ruby
ImportJob.attribute_names
# => ["file_path", "skip_header", "delimiter", "batch_size", "started_at"]

job.attributes
# => {"file_path"=>nil, "skip_header"=>true, "delimiter"=>",", "batch_size"=>1000, "started_at"=>nil}
```

**Custom attribute types:**

```ruby
class MoneyType < ActiveModel::Type::Value
  def cast(value)
    case value
    when String then BigDecimal(value.gsub(/[$,]/, ""))
    when Numeric then BigDecimal(value.to_s)
    else value
    end
  end
end

ActiveModel::Type.register(:money, MoneyType)

class Invoice
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :total, :money
end

Invoice.new(total: "$1,234.56").total  # => 0.123456e4 (BigDecimal)
```

## ActiveModel::Naming

Usually included automatically via `Model`/`API`. Key methods on `model_name`:

```ruby
class Admin::UserForm
  include ActiveModel::Model
end

Admin::UserForm.model_name.name              # => "Admin::UserForm"
Admin::UserForm.model_name.singular          # => "admin_user_form"
Admin::UserForm.model_name.plural            # => "admin_user_forms"
Admin::UserForm.model_name.element           # => "user_form"
Admin::UserForm.model_name.human             # => "User form"
Admin::UserForm.model_name.param_key         # => "admin_user_form"
Admin::UserForm.model_name.route_key         # => "admin_user_forms"
Admin::UserForm.model_name.singular_route_key # => "admin_user_form"
Admin::UserForm.model_name.i18n_key          # => :"admin/user_form"
Admin::UserForm.model_name.collection        # => "admin/user_forms"
```

**Override to strip namespace:**

```ruby
class Admin::UserForm
  include ActiveModel::Model

  def self.model_name
    ActiveModel::Name.new(self, nil, "UserForm")
  end
end

Admin::UserForm.model_name.param_key  # => "user_form" (not "admin_user_form")
```

## ActiveModel::Translation

Integrates with Rails I18n. Included automatically via `Model`/`API`.

```yaml
# config/locales/en.yml
en:
  activemodel:
    models:
      contact_form: "Contact Request"
    attributes:
      contact_form:
        name: "Your Name"
        email: "Email Address"
        phone: "Phone Number"
    errors:
      models:
        contact_form:
          attributes:
            name:
              blank: "is required — we need to know who you are"
            email:
              invalid: "doesn't look like a valid email"
```

```ruby
ContactForm.model_name.human                    # => "Contact Request"
ContactForm.human_attribute_name(:name)          # => "Your Name"
ContactForm.human_attribute_name(:phone)         # => "Phone Number"
```

## ActiveModel::Conversion

Provides `to_model`, `to_key`, `to_param`, `to_partial_path`. Included via `Model`/`API`.

```ruby
class Article
  include ActiveModel::Model
  attr_accessor :id, :title

  def persisted?
    id.present?
  end
end

article = Article.new(id: 5, title: "Hello")
article.to_model         # => self
article.to_key           # => [5]
article.to_param         # => "5"
article.to_partial_path  # => "articles/article"

unpersisted = Article.new(title: "Draft")
unpersisted.to_key    # => nil
unpersisted.to_param  # => nil
```

**`to_partial_path`** lets `render @article` find `app/views/articles/_article.html.erb`.

## ActiveModel::SecurePassword

Adds bcrypt-based password handling. Requires the `bcrypt` gem.

```ruby
class Account
  include ActiveModel::Model
  include ActiveModel::SecurePassword

  has_secure_password
  has_secure_password :recovery_password, validations: false

  attr_accessor :password_digest, :recovery_password_digest
end

account = Account.new
account.password = "secret123"
account.password_confirmation = "secret123"
account.valid?  # => true

account.authenticate("secret123")   # => account
account.authenticate("wrong")       # => false

# Named passwords:
account.recovery_password = "backup42"
account.authenticate_recovery_password("backup42")  # => account
```

**Default validations (on the primary password):**
1. Password must be present on creation
2. Password confirmation must match (if `password_confirmation` is set)
3. Max 72 bytes (bcrypt limitation)

Pass `validations: false` to skip these for secondary passwords.

## ActiveModel::AttributeMethods

Low-level module for defining dynamic attribute methods with prefixes/suffixes. Most agents won't need this directly — it's used internally by Active Record.

```ruby
class DataPoint
  include ActiveModel::AttributeMethods

  attribute_method_prefix "clear_"
  attribute_method_suffix "_present?"

  define_attribute_methods :value, :label

  attr_accessor :value, :label

  private

  def clear_attribute(attr)
    public_send("#{attr}=", nil)
  end

  def attribute_present?(attr)
    public_send(attr).present?
  end
end

dp = DataPoint.new
dp.value = 42
dp.value_present?   # => true
dp.clear_value
dp.value            # => nil
```

Also supports `alias_attribute`:

```ruby
alias_attribute :full_name, :name
# Now full_name and name are interchangeable
```
