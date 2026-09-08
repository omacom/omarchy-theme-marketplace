# Thor Actions Reference

File manipulation methods available in all Rails generators via Thor inheritance.

## File Creation & Copying

```ruby
# Create a file with content
create_file "config/initializers/my_init.rb", <<~RUBY
  MyApp.configure do |config|
    config.setting = true
  end
RUBY

# Copy a template (ERB processed)
template "service.rb.tt", "app/services/#{file_name}_service.rb"

# Copy a file without ERB processing
copy_file "config.yml", "config/my_config.yml"

# Create empty directory
empty_directory "app/services"
```

## File Modification

```ruby
# Append to file
append_to_file "Gemfile", "\ngem 'devise'"

# Prepend to file
prepend_to_file "app/models/user.rb", "# frozen_string_literal: true\n\n"

# Insert at specific point
inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
  "  root to: 'home#index'\n"
end

# Insert before a line
inject_into_file "app/models/user.rb", before: "end\n" do
  "  has_many :posts\n"
end

# Global search and replace
gsub_file "config/database.yml", /sqlite3/, "postgresql"

# Comment/uncomment lines
comment_lines "Gemfile", /gem 'sqlite3'/
uncomment_lines "config/environments/production.rb", /config.force_ssl/
```

## Running Commands

```ruby
# Run shell command
run "bundle install"

# Run Rails command
rails_command "db:migrate"

# Run Rake task
rake "db:seed"

# Run inside a directory
inside("lib") do
  run "touch my_file.rb"
end
```

## User Interaction

```ruby
# Ask a question
name = ask("What's the project name?")

# Yes/no question
if yes?("Install Devise?")
  gem "devise"
end

# Say something
say "Creating service object...", :green
say_status "create", "app/services/foo_service.rb", :green
```

## Conflict Resolution

```ruby
# Check if file exists
if File.exist?(destination)
  say "File already exists, skipping", :yellow
  return
end

# Or use built-in behavior_on_conflict
# Generator automatically asks: Ynaqdh (Yes/No/All/Quit/Diff/Help)
```
