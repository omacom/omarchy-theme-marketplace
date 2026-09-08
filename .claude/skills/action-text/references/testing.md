# Testing Action Text and Troubleshooting

## Model Tests

```ruby
require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "stores and retrieves rich text content" do
    article = Article.create!(title: "Test", content: "<h1>Hello</h1><p>World</p>")
    article.reload

    assert_equal "Hello\nWorld", article.content.to_plain_text.strip
    assert_includes article.content.to_s, "<h1>Hello</h1>"
  end

  test "content can be blank" do
    article = Article.create!(title: "Test")
    assert article.content.blank?
  end

  test "content can contain attachments" do
    article = articles(:with_content)
    # Use with_rich_text_content_and_embeds to test attachment loading
    loaded = Article.with_rich_text_content_and_embeds.find(article.id)
    assert loaded.content.present?
  end

  test "custom validation on rich text length" do
    article = Article.new(title: "Test")
    article.content = "x" * 20_000  # Exceeds max
    refute article.valid?
    assert_includes article.errors[:content], "is too long (maximum 10,000 characters)"
  end
end
```

## Request Tests

```ruby
require "test_helper"

class ArticlesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:active_user)
    sign_in @user
  end

  test "POST /articles with rich text content" do
    assert_difference "Article.count", 1 do
      post articles_path, params: {
        article: {
          title: "Test Article",
          content: "<h1>Hello</h1><p>This is <strong>rich</strong> text.</p>"
        }
      }
    end

    article = Article.last
    assert_equal "Test Article", article.title
    assert_includes article.content.to_plain_text, "rich"
    assert_includes article.content.to_s, "<strong>rich</strong>"
  end

  test "PATCH /articles/:id updates rich text" do
    article = articles(:published)

    patch article_path(article), params: {
      article: { content: "<p>Updated content</p>" }
    }

    assert_equal "Updated content", article.reload.content.to_plain_text.strip
  end
end
```

## System Tests (Editor Interaction)

```ruby
require "application_system_test_case"

class RichTextEditorTest < ApplicationSystemTestCase
  setup do
    sign_in users(:active_user)
  end

  # Trix editor
  test "writes content in Trix editor" do
    visit new_article_path

    fill_in "Title", with: "My Article"

    find("trix-editor").click
    find("trix-editor").set("Hello from the editor")

    click_on "Create Article"
    assert_text "Hello from the editor"
  end

  # Lexxy editor
  test "writes content in Lexxy editor" do
    visit new_article_path

    fill_in "Title", with: "My Article"

    find("lexxy-editor").click
    find("lexxy-editor").set("Hello from Lexxy")

    click_on "Create Article"
    assert_text "Hello from Lexxy"
  end

  test "attaches image via drag and drop" do
    visit new_article_path

    # Attach file to the hidden file input
    find("trix-editor").click
    attach_file file_fixture("test_image.png"), make_visible: true

    click_on "Create Article"
    assert_selector "img.attachment__image"
  end
end
```

## Fixture with Rich Text

```yaml
# test/fixtures/articles.yml
published:
  title: "Published Article"
  author: active_user

with_content:
  title: "Article with Content"
  author: active_user

# test/fixtures/action_text/rich_texts.yml
published_content:
  record: published (Article)
  name: content
  body: "<p>This is published content with <strong>formatting</strong>.</p>"

with_content_body:
  record: with_content (Article)
  name: content
  body: "<h1>Heading</h1><p>Paragraph with <a href='https://example.com'>link</a>.</p>"
```

## Testing Attachables

```ruby
require "test_helper"

class UserMentionTest < ActiveSupport::TestCase
  test "user can be embedded as attachable" do
    user = users(:active_user)
    sgid = user.attachable_sgid

    html = %(<action-text-attachment sgid="#{sgid}"></action-text-attachment>)
    content = ActionText::Content.new(html)

    assert_equal [user], content.attachables
  end

  test "missing user renders fallback partial" do
    sgid = users(:active_user).attachable_sgid
    users(:active_user).destroy!

    html = %(<action-text-attachment sgid="#{sgid}"></action-text-attachment>)
    content = ActionText::Content.new(html)

    # Verify it doesn't raise when the record is missing
    assert_nothing_raised { content.to_s }
  end
end
```

---

## Troubleshooting

### Images Not Rendering in Editor

**Cause:** Missing `libvips` dependency.

```bash
# Debian/Ubuntu
sudo apt install libvips

# macOS
brew install vips
```

### Editor Not Appearing

**Cause:** Missing JavaScript imports.

Check `app/javascript/application.js`:
```js
import "trix"
import "@rails/actiontext"
```

Or for importmaps, check `config/importmap.rb`:
```ruby
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
```

### Content Renders as Plain Text (Not HTML)

**Cause:** Using `@article.content.body` instead of `@article.content`.

```erb
<%# WRONG: renders raw HTML as text %>
<%= @article.content.body %>

<%# CORRECT: renders sanitized HTML %>
<%= @article.content %>
```

### Content Looks Different in Editor vs Rendered View

**Cause:** Editor and rendered content use different stylesheets.

The editor has its own internal styles. The rendered content uses your `.trix-content` or `.lexxy-content` styles. Keep both in sync.

### Styles Not Applying to Lexxy Editor

**Cause:** Wrong stylesheet load order.

```erb
<%# Lexxy CSS must load FIRST, then your overrides %>
<%= stylesheet_link_tag "lexxy" %>
<%= stylesheet_link_tag :app %>
```

### N+1 Queries in Views

**Cause:** Not preloading rich text associations.

```ruby
# Controller
@articles = Article.with_rich_text_content_and_embeds
```

### ActionText::RichText Record Not Found

**Cause:** `action_text:install` was never run, or migrations weren't executed.

```bash
bin/rails action_text:install
bin/rails db:migrate
```

### Turbo/Stimulus Conflicts with Editor

**Cause:** Turbo replacing the DOM removes the editor instance.

```erb
<%# Wrap editor in a Turbo permanent frame %>
<div id="editor-container" data-turbo-permanent>
  <%= form.rich_text_area :content %>
</div>
```

### File Uploads Fail Silently

**Cause:** Active Storage not configured or missing service.

Check `config/storage.yml` and `config/environments/*.rb`:
```ruby
config.active_storage.service = :local  # or :amazon, :google, etc.
```

### Blank Content After Save

**Cause:** Strong parameters not permitting the rich text attribute.

```ruby
# Ensure the attribute is permitted
params.expect(article: [:title, :content])
```
