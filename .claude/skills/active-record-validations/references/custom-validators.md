# Custom Validators Patterns

EachValidator, Validator classes, and PORO validators for reusable and complex validation logic.

## EachValidator — the workhorse

File: `app/validators/phone_number_validator.rb`

```ruby
class PhoneNumberValidator < ActiveModel::EachValidator
  PHONE_REGEX = /\A\+?[1-9]\d{6,14}\z/

  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_blank]
    unless PHONE_REGEX.match?(value)
      record.errors.add(attribute, options[:message] || :invalid_phone)
    end
  end
end

# Usage:
validates :phone, phone_number: true
validates :fax, phone_number: { allow_blank: true, message: "doesn't look like a phone number" }
```

## EachValidator with options

```ruby
class FileSizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.attached?
    max = options[:max] || 10.megabytes
    if value.blob.byte_size > max
      record.errors.add(attribute, options[:message] || "is too large (max #{max / 1.megabyte}MB)")
    end
  end
end

# Usage:
validates :avatar, file_size: { max: 5.megabytes }
```

## Validator class (cross-field)

```ruby
class DateRangeValidator < ActiveModel::Validator
  def validate(record)
    start_field = options[:start] || :start_date
    end_field = options[:end] || :end_date

    start_val = record.send(start_field)
    end_val = record.send(end_field)

    return if start_val.blank? || end_val.blank?

    if end_val <= start_val
      record.errors.add(end_field, "must be after #{start_field.to_s.humanize.downcase}")
    end

    if options[:max_span] && (end_val - start_val) > options[:max_span]
      record.errors.add(end_field, "range cannot exceed #{options[:max_span].inspect}")
    end
  end
end

# Usage:
validates_with DateRangeValidator, start: :check_in, end: :check_out, max_span: 30.days
```

## PORO validator (needs instance state)

When your validator needs per-validation instance variables:

```ruby
class Invoice < ApplicationRecord
  validate do |invoice|
    TaxValidator.new(invoice).validate
  end
end

class TaxValidator
  def initialize(invoice)
    @invoice = invoice
    @tax_rules = TaxRule.for_region(invoice.region)
  end

  def validate
    return if @invoice.tax_exempt?
    validate_tax_rate
    validate_tax_amount
  end

  private

  def validate_tax_rate
    unless @tax_rules.valid_rate?(@invoice.tax_rate)
      @invoice.errors.add(:tax_rate, "is not valid for #{@invoice.region}")
    end
  end

  def validate_tax_amount
    expected = @invoice.subtotal * @invoice.tax_rate
    unless (@invoice.tax_amount - expected).abs < 0.01
      @invoice.errors.add(:tax_amount, "doesn't match expected tax calculation")
    end
  end
end
```
