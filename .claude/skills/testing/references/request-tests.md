# Request Tests In Depth

Detailed patterns for writing request/integration tests in Rails.

---

## Base Class and Inheritance

Request tests inherit from `ActionDispatch::IntegrationTest`, which gives you the full HTTP verb methods, session, cookies, and redirect following.

```ruby
class ArticlesControllerTest < ActionDispatch::IntegrationTest
  # This is the modern approach — despite living in test/controllers/
  # These ARE integration/request tests, not "functional" controller tests
end
```

## All HTTP Methods

```ruby
get    url, params: {}, headers: {}, env: {}, xhr: false, as: nil
post   url, params: {}, headers: {}, env: {}, xhr: false, as: nil
patch  url, params: {}, headers: {}, env: {}, xhr: false, as: nil
put    url, params: {}, headers: {}, env: {}, xhr: false, as: nil
delete url, params: {}, headers: {}, env: {}, xhr: false, as: nil
head   url, params: {}, headers: {}, env: {}, xhr: false, as: nil
```

## Testing JSON APIs

```ruby
class Api::V1::ArticlesTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:published)
    @headers = {
      "Authorization" => "Bearer #{api_tokens(:admin).token}",
      "Accept" => "application/json"
    }
  end

  test "GET /api/v1/articles returns articles" do
    get api_v1_articles_url, headers: @headers, as: :json
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body
    assert body.any? { |a| a["id"] == @article.id }
  end

  test "POST /api/v1/articles creates article" do
    assert_difference "Article.count", 1 do
      post api_v1_articles_url,
        params: { article: { title: "API Created", body: "Via JSON" } },
        headers: @headers,
        as: :json
    end
    assert_response :created

    body = response.parsed_body
    assert_equal "API Created", body["title"]
  end

  test "POST /api/v1/articles with invalid data returns errors" do
    assert_no_difference "Article.count" do
      post api_v1_articles_url,
        params: { article: { title: "" } },
        headers: @headers,
        as: :json
    end
    assert_response :unprocessable_entity

    body = response.parsed_body
    assert_includes body["errors"]["title"], "can't be blank"
  end

  test "GET /api/v1/articles without auth returns 401" do
    get api_v1_articles_url, as: :json
    assert_response :unauthorized
  end
end
```

## Testing Redirects

```ruby
test "non-admin is redirected to root" do
  sign_in_as users(:regular)
  get admin_dashboard_url
  assert_redirected_to root_url

  # Follow the redirect and check the final page
  follow_redirect!
  assert_response :success
  assert_select ".flash-alert", /not authorized/i
end
```

## Testing Flash Messages

```ruby
test "displays success flash after create" do
  sign_in_as users(:admin)
  post articles_url, params: { article: { title: "New", body: "Article" } }
  assert_equal "Article was successfully created.", flash[:notice]
end
```

## Testing with Cookies and Sessions

```ruby
test "remembers user preference" do
  get articles_url
  assert_nil cookies[:view_mode]

  patch preferences_url, params: { view_mode: "compact" }
  assert_equal "compact", cookies[:view_mode]
end
```

## Testing File Uploads

```ruby
test "uploads avatar" do
  sign_in_as users(:admin)

  avatar = fixture_file_upload("test/fixtures/files/avatar.png", "image/png")

  patch user_url(@user), params: { user: { avatar: avatar } }
  assert_redirected_to user_url(@user)

  @user.reload
  assert @user.avatar.attached?
end
```

## Testing Turbo Stream Responses

```ruby
test "create returns turbo stream" do
  sign_in_as users(:admin)

  post articles_url, params: { article: { title: "Turbo", body: "Stream" } },
    as: :turbo_stream

  assert_response :success
  assert_match "turbo-stream", response.body
  assert_match "append", response.body
end
```

## DOM Assertions in Request Tests

```ruby
test "index page shows articles" do
  get articles_url
  assert_response :success

  # Check specific HTML elements
  assert_select "h1", "Articles"
  assert_select ".article", count: Article.count
  assert_select ".article .title", @article.title

  # Nested assertions
  assert_select "ul.articles" do
    assert_select "li", minimum: 1
  end

  # Check absence
  assert_select ".admin-controls", count: 0
end
```

## Testing with Basic Auth

```ruby
test "requires basic auth" do
  get admin_url
  assert_response :unauthorized

  credentials = ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret")
  get admin_url, headers: { "Authorization" => credentials }
  assert_response :success
end
```

## File Upload Testing

### In Request Tests

```ruby
test "uploads a document" do
  sign_in_as users(:admin)
  file = fixture_file_upload("test/fixtures/files/document.pdf", "application/pdf")

  assert_difference "Document.count", 1 do
    post documents_url, params: { document: { file: file, title: "Test Doc" } }
  end

  assert_redirected_to documents_url
  assert Document.last.file.attached?
end
```

### In System Tests

```ruby
test "uploads avatar via form" do
  sign_in users(:admin)
  visit edit_profile_path

  attach_file "Avatar", Rails.root.join("test/fixtures/files/avatar.png")
  click_on "Save"

  assert_text "Profile updated"
end
```

### Multiple File Uploads

```ruby
test "uploads multiple images" do
  sign_in_as users(:admin)

  files = [
    fixture_file_upload("test/fixtures/files/photo1.jpg", "image/jpeg"),
    fixture_file_upload("test/fixtures/files/photo2.jpg", "image/jpeg")
  ]

  post gallery_images_url, params: { images: files }
  assert_response :redirect
end
```
