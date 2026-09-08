# Serialization

## Basic Serialization (`ActiveModel::Serialization`)

```ruby
class Report
  include ActiveModel::Serialization

  attr_accessor :title, :generated_at, :data

  def attributes
    { "title" => nil, "generated_at" => nil, "data" => nil }
  end
end

report = Report.new
report.title = "Q4 Sales"
report.generated_at = Time.current
report.data = { total: 50_000 }

report.serializable_hash
# => {"title"=>"Q4 Sales", "generated_at"=>..., "data"=>{:total=>50000}}

report.serializable_hash(only: [:title])
# => {"title"=>"Q4 Sales"}

report.serializable_hash(except: [:data])
# => {"title"=>"Q4 Sales", "generated_at"=>...}
```

## JSON Serialization (`ActiveModel::Serializers::JSON`)

Includes Serialization:

```ruby
class Report
  include ActiveModel::Serializers::JSON

  attr_accessor :title, :data

  def attributes
    { "title" => nil, "data" => nil }
  end

  def attributes=(hash)
    hash.each { |k, v| public_send("#{k}=", v) }
  end
end

report = Report.new(title: "Q4")
report.as_json   # => {"title"=>"Q4", "data"=>nil}
report.to_json   # => '{"title":"Q4","data":null}'

# Deserialize from JSON:
report2 = Report.new
report2.from_json('{"title":"Q4","data":{"total":50000}}')
report2.title  # => "Q4"
report2.data   # => {"total" => 50000}
```

**Critical:** You must define an `attributes` method that returns a hash with string keys. The values are defaults (usually `nil`). This tells the serializer which attributes to include.
