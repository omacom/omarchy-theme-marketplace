# Testing Turbo

Integration tests, system tests, and broadcast assertions for Turbo responses.

---

## Testing Turbo Stream Responses

```ruby
class PostsControllerTest < ActionDispatch::IntegrationTest
  test "create responds with turbo stream" do
    sign_in users(:active_user)

    post posts_path, params: { post: { title: "Test", body: "Content" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "turbo-stream", response.content_type
    assert_match "prepend", response.body
    assert_match "posts", response.body  # target
  end

  test "create with invalid data returns unprocessable entity" do
    sign_in users(:active_user)

    post posts_path, params: { post: { title: "" } }

    assert_response :unprocessable_entity
  end
end
```

## Testing Turbo Frame Responses

```ruby
test "edit loads in turbo frame" do
  sign_in users(:active_user)
  post = posts(:published)

  get edit_post_path(post),
      headers: { "Turbo-Frame" => dom_id(post) }

  assert_response :success
  assert_select "turbo-frame##{dom_id(post)}"
end
```

## System Tests with Turbo

```ruby
class PostsSystemTest < ApplicationSystemTestCase
  test "inline edit with turbo frame" do
    sign_in users(:active_user)
    post = posts(:published)

    visit posts_path

    within "##{dom_id(post)}" do
      click_on "Edit"
      fill_in "Title", with: "Updated Title"
      click_on "Update"
    end

    # Frame updates in place — no full page navigation
    within "##{dom_id(post)}" do
      assert_text "Updated Title"
    end
  end

  test "turbo stream appends new post" do
    sign_in users(:active_user)
    visit posts_path

    fill_in "Title", with: "New Post"
    click_on "Create"

    # New post appears without page reload
    assert_selector "#posts .post", count: Post.count
    assert_text "New Post"
  end
end
```

## Testing Broadcasts

```ruby
class PostBroadcastTest < ActiveSupport::TestCase
  test "broadcasts append on create" do
    assert_broadcasts_on("posts", count: 1) do
      Post.create!(title: "Test", body: "Content")
    end
  end

  # Or test the broadcast content
  test "broadcasts to project stream" do
    project = projects(:active)

    assert_broadcast_on(project, count: 1) do
      project.posts.create!(title: "Test", body: "Content")
    end
  end
end
```
