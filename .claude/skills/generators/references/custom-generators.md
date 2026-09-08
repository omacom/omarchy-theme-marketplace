# Creating Custom Generators, Hooks, and Resolution

In-depth guide to building custom generators, composition via hooks, and generator resolution order.

## Generator Base Classes

| Base Class | Requires Argument | Use For |
|------------|-------------------|---------|
| `Rails::Generators::Base` | No | Generators that don't take a NAME argument |
| `Rails::Generators::NamedBase` | Yes (NAME) | Generators that create something named (most common) |

## Full Custom Generator Example

```ruby
# lib/generators/service/service_generator.rb
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  # Arguments (positional, after NAME)
  argument :methods, type: :array, default: [], banner: "method method"

  # Options (--flag style)
  class_option :module, type: :string, default: nil,
    desc: "Wrap service in a module"
  class_option :skip_test, type: :boolean, default: false,
    desc: "Skip test file generation"

  def create_service_file
    template "service.rb.tt", File.join("app/services", class_path, "#{file_name}_service.rb")
  end

  def create_test_file
    return if options[:skip_test]
    template "service_test.rb.tt", File.join("test/services", class_path, "#{file_name}_service_test.rb")
  end

  # Hook into test framework (like Rails built-in generators do)
  hook_for :test_framework, as: :service

  private

  def module_name
    options[:module]
  end

  def service_class_name
    "#{class_name}Service"
  end
end
```

## Template (.tt) Files

Templates use ERB and have access to all generator methods:

```ruby
# lib/generators/service/templates/service.rb.tt
<% if module_name -%>
module <%= module_name %>
  <% end -%>
class <%= service_class_name %>
  def initialize(<%= file_name %>)
    @<%= file_name %> = <%= file_name %>
  end

<% methods.each do |method| -%>
  def <%= method %>
    # TODO: implement
  end

<% end -%>
  def call
    # TODO: implement
  end

  private

  attr_reader :<%= file_name %>
<% if module_name -%>
end
<% end -%>
end
```

## USAGE File

```
# lib/generators/service/USAGE
Description:
    Creates a service object class and test.

Example:
    bin/rails generate service ProcessPayment charge refund

    This will create:
        app/services/process_payment_service.rb
        test/services/process_payment_service_test.rb
```

---

## Generator Hooks and Composition

### hook_for

Generators can delegate parts of their work to other generators:

```ruby
class ScaffoldGenerator < Rails::Generators::NamedBase
  hook_for :orm, required: true                    # Invokes active_record:model
  hook_for :resource_route, required: true         # Invokes resource_route
  hook_for :scaffold_controller, required: true    # Invokes scaffold_controller
  hook_for :test_framework, as: :scaffold          # Invokes test_unit:scaffold
end
```

### Overriding Hooked Generators

```ruby
# config/application.rb
config.generators do |g|
  g.helper :my_helper              # Replace helper generator
  g.test_framework :my_test_unit   # Replace test generator
  g.orm :my_orm                    # Replace ORM generator
  g.template_engine :slim          # Use Slim instead of ERB
end
```

### Fallbacks

When you want to override only SOME generators in a namespace:

```ruby
# config/application.rb
config.generators do |g|
  g.test_framework :my_test_unit
  g.fallbacks[:my_test_unit] = :test_unit
end
```

This uses `my_test_unit:model` if it exists, but falls back to `test_unit:controller` etc.

---

## Generator Resolution Order

When you run `bin/rails g foo`, Rails searches for the generator in this order:

1. `rails/generators/foo/foo_generator.rb`
2. `generators/foo/foo_generator.rb`
3. `rails/generators/foo_generator.rb`
4. `generators/foo_generator.rb`

For namespaced generators like `bin/rails g my_gem:install`:

1. `rails/generators/my_gem/install/install_generator.rb`
2. `generators/my_gem/install/install_generator.rb`
3. `rails/generators/my_gem/install_generator.rb`
4. `generators/my_gem/install_generator.rb`

### Where to Place Custom Generators

| Location | When |
|----------|------|
| `lib/generators/` | App-specific generators |
| `lib/generators/rails/` | Override Rails built-in generators |
| Gem's `lib/generators/` | Gem-provided generators |
