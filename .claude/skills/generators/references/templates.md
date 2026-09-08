# Overriding Built-In Templates and Application Templates

How to customize generator output and automate new Rails app setup.

## Overriding Built-In Templates

### Template Override Locations

Place templates in `lib/templates/` mirroring the generator's namespace:

```
lib/templates/
├── active_record/
│   ├── migration/
│   │   ├── create_table_migration.rb.tt
│   │   └── migration.rb.tt
│   └── model/
│       └── model.rb.tt
├── erb/
│   ├── controller/
│   │   └── view.html.erb.tt
│   └── scaffold/
│       ├── _form.html.erb.tt
│       ├── _resource.html.erb.tt
│       ├── edit.html.erb.tt
│       ├── index.html.erb.tt
│       ├── new.html.erb.tt
│       └── show.html.erb.tt
├── rails/
│   └── scaffold_controller/
│       └── controller.rb.tt
└── test_unit/
    ├── model/
    │   └── unit_test.rb.tt
    ├── scaffold/
    │   └── functional_test.rb.tt
    └── integration/
        └── integration_test.rb.tt
```

### Finding Original Templates

To find the original template to copy and modify:

```bash
# Find where railties gem is installed
bundle show railties

# Browse generator templates
find $(bundle show railties)/lib/rails/generators -name "*.tt" | sort

# Copy a template to override it
cp $(bundle show railties)/lib/rails/generators/erb/scaffold/templates/index.html.erb.tt \
   lib/templates/erb/scaffold/index.html.erb.tt
```

### Example: Custom Model Template

```ruby
# lib/templates/active_record/model/model.rb.tt
<% module_namespacing do -%>
class <%= class_name %> < <%= parent_class_name.classify %>
<% attributes.select(&:reference?).each do |attribute| -%>
  belongs_to :<%= attribute.name %><%= ", polymorphic: true" if attribute.polymorphic? %>
<% end -%>
<% attributes.select(&:token?).each do |attribute| -%>
  has_secure_token<%= ":#{attribute.name}" unless attribute.name == "token" %>
<% end -%>
<% if attributes.any?(&:password_digest?) -%>
  has_secure_password
<% end -%>

  # Validations
<% attributes.reject(&:reference?).each do |attribute| -%>
  validates :<%= attribute.name %>, presence: true
<% end -%>
end
<% end -%>
```

### Example: Custom Scaffold Views

```erb
<%# lib/templates/erb/scaffold/index.html.erb.tt %>
<div class="container mx-auto px-4">
  <h1 class="text-2xl font-bold mb-4"><%%= @<%= plural_table_name %>.count %> <%= human_name.pluralize %></h1>

  <%%= link_to "New <%= human_name %>", new_<%= singular_route_name %>_path, class: "btn btn-primary" %>

  <div class="mt-4 space-y-4">
    <%% @<%= plural_table_name %>.each do |<%= singular_table_name %>| %>
      <%%= render <%= singular_table_name %> %>
    <%% end %>
  </div>
</div>
```

---

## Application Templates

Templates automate new Rails app setup. Used with `rails new -m template.rb`.

### Template API Methods

```ruby
# template.rb

# Add gems
gem "devise"
gem "sidekiq"
gem_group :development, :test do
  gem "debug"
  gem "brakeman"
end

# Run after bundle install
after_bundle do
  # Run generators
  generate "devise:install"
  generate "devise", "User"

  # Run Rails commands
  rails_command "db:migrate"

  # Add routes
  route 'root to: "home#index"'

  # Add environment config
  environment 'config.action_mailer.default_url_options = {host: "localhost:3000"}', env: "development"

  # Create initializer
  initializer "sidekiq.rb", <<~RUBY
    Sidekiq.configure_server do |config|
      config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
    end
  RUBY

  # Create files
  file "app/services/application_service.rb", <<~RUBY
    class ApplicationService
      def self.call(...)
        new(...).call
      end
    end
  RUBY

  # Git
  git :init
  git add: "."
  git commit: "-m 'Initial commit'"
end
```

### Using Templates

```bash
# With new app
rails new myapp -m ~/template.rb
rails new myapp -m https://example.com/template.rb

# Apply to existing app
bin/rails app:template LOCATION=~/template.rb
bin/rails app:template LOCATION=https://example.com/template.rb
```
