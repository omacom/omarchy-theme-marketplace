# System Tests In Depth

Detailed patterns for writing and configuring system tests with Capybara.

> **See also:** The main SKILL.md for when to use system tests vs request tests.

---

## Capybara DSL Quick Reference

**Navigation:**
```ruby
visit articles_path
visit "/articles"
go_back
go_forward
refresh
```

**Finders:**
```ruby
find("#element-id")
find(".class-name")
find("input[name='email']")
find(:css, "button.primary")
find(:xpath, "//button[@type='submit']")
find_button("Submit")
find_field("Email")
find_link("Sign in")
```

**Interactions:**
```ruby
click_on "Button or Link Text"
click_button "Submit"
click_link "Sign in"
fill_in "Email", with: "user@example.com"
choose "Option A"          # radio button
check "Remember me"        # checkbox
uncheck "Subscribe"        # checkbox
select "Admin", from: "Role"
attach_file "Avatar", Rails.root.join("test/fixtures/files/avatar.png")
```

**Assertions:**
```ruby
assert_text "Welcome"
assert_no_text "Error"
assert_selector "h1", text: "Dashboard"
assert_no_selector ".error-message"
assert_current_path articles_path
assert_link "Edit"
assert_button "Submit"
assert_field "Email", with: "user@example.com"
assert_checked_field "Remember me"
assert_unchecked_field "Subscribe"
```

**Scoping:**
```ruby
within "#sidebar" do
  click_on "Settings"
end

within_table "Users" do
  assert_text "admin@example.com"
end

within_fieldset "Address" do
  fill_in "City", with: "Portland"
end
```

## Configuring Cuprite (Faster Alternative to Selenium)

```ruby
# Gemfile
group :test do
  gem "cuprite"
end

# test/application_system_test_case.rb
require "test_helper"
require "capybara/cuprite"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, options: {
    window_size: [1400, 1400],
    browser_options: { "no-sandbox": nil },
    headless: true,
    process_timeout: 10,
    timeout: 10
  }
end
```

## Debugging System Tests

```ruby
# Take screenshot at any point
take_screenshot

# Save and open current page HTML
save_page

# Print current page text (useful in CI logs)
puts page.text

# Use visible browser for debugging
# Temporarily change to:
driven_by :selenium, using: :chrome  # non-headless

# Pause execution (add a breakpoint)
debugger  # Rails 7+
```

## Testing JavaScript Interactions

```ruby
test "live search filters results" do
  visit articles_path

  fill_in "Search", with: "rails"

  # Capybara auto-waits for this assertion
  assert_selector ".article", count: 2
  assert_text "Rails Guide"
  assert_no_text "Django Tutorial"
end

test "modal opens and closes" do
  visit articles_path

  click_on "Delete"
  assert_selector "#confirm-modal", visible: true
  assert_text "Are you sure?"

  click_on "Cancel"
  assert_no_selector "#confirm-modal", visible: true
end

test "drag and drop reorders items" do
  visit board_path(@board)

  source = find("#card-1")
  target = find("#card-3")
  source.drag_to(target)

  # Verify new order
  assert_selector "#card-list li:first-child", text: @card3.title
end
```

## System Tests with Turbo

```ruby
test "inline edit with turbo frame" do
  visit article_path(@article)

  # Click edit within a turbo frame
  within "#article-header" do
    click_on "Edit"
    # Turbo replaces the frame content
    fill_in "Title", with: "Updated Title"
    click_on "Save"
  end

  # Frame is replaced with show content
  within "#article-header" do
    assert_text "Updated Title"
    assert_no_selector "input[name='article[title]']"
  end
end
```

## Testing Turbo & Stimulus

### Turbo Frame Responses (Request Tests)

```ruby
test "edit renders turbo frame" do
  sign_in_as users(:admin)

  get edit_article_url(@article),
    headers: { "Turbo-Frame" => "article_#{@article.id}" }

  assert_response :success
  assert_select "turbo-frame#article_#{@article.id}"
end
```

### Turbo Stream Responses (Request Tests)

```ruby
test "create returns turbo stream when requested" do
  sign_in_as users(:admin)

  post articles_url,
    params: { article: { title: "Turbo", body: "Test" } },
    as: :turbo_stream

  assert_response :success
  assert_includes response.media_type, "turbo-stream"
end
```

### Stimulus in System Tests

```ruby
test "character counter updates live" do
  visit new_article_path

  fill_in "Body", with: "x" * 100

  # Stimulus controller updates counter
  assert_selector "[data-character-count]", text: "100/500"

  fill_in "Body", with: "x" * 501
  assert_selector "[data-character-count]", text: "501/500"
  assert_selector "[data-character-count].over-limit"
end
```
