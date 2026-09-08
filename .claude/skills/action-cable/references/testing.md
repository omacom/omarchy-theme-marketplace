# Testing Patterns

## Channel Tests

```ruby
require "test_helper"

class ChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:active_user)
    @room = rooms(:general)
    # Stub the connection's current_user
    stub_connection current_user: @user
  end

  # Subscription tests
  test "subscribes successfully with valid room" do
    subscribe room_id: @room.id
    assert subscription.confirmed?
  end

  test "rejects subscription without room" do
    subscribe room_id: nil
    assert subscription.rejected?
  end

  test "rejects subscription for inaccessible room" do
    private_room = rooms(:private_room)
    subscribe room_id: private_room.id
    assert subscription.rejected?
  end

  # Stream tests
  test "streams from room" do
    subscribe room_id: @room.id
    assert_has_stream_for @room
  end

  test "streams with string name" do
    subscribe room_id: @room.id
    assert_has_stream "chat_#{@room.id}"
  end

  # Action tests
  test "speak creates a message" do
    subscribe room_id: @room.id
    assert_difference "Message.count", 1 do
      perform :speak, body: "Hello, world!"
    end
  end

  test "speak broadcasts to room" do
    subscribe room_id: @room.id

    assert_broadcasts("chat_#{@room.id}", 1) do
      perform :speak, body: "Hello!"
    end
  end

  # Unsubscribe tests
  test "marks user offline on unsubscribe" do
    subscribe room_id: @room.id
    assert @user.reload.online?

    unsubscribe
    refute @user.reload.online?
  end
end
```

## Connection Tests

```ruby
require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup do
    @user = users(:active_user)
  end

  test "connects with authenticated user" do
    connect cookies: { user_id: @user.id }
    assert_equal @user, connection.current_user
  end

  test "rejects connection without authentication" do
    assert_reject_connection { connect }
  end

  test "rejects connection with invalid user" do
    assert_reject_connection do
      connect cookies: { user_id: "nonexistent" }
    end
  end

  # Token-based auth test
  test "connects with valid token" do
    token = @user.generate_auth_token
    connect params: { token: token }
    assert_equal @user, connection.current_user
  end
end
```

## Broadcast Assertions in Integration Tests

```ruby
class MessagesIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:active_user)
    @room = rooms(:general)
    sign_in @user
  end

  test "creating a message broadcasts to the room channel" do
    assert_broadcasts("chat_#{@room.id}", 1) do
      post room_messages_path(@room),
        params: { message: { body: "Hello!" } }
    end
  end

  test "broadcast contains expected data" do
    assert_broadcast_on("chat_#{@room.id}",
      hash_including("type" => "new_message")
    ) do
      post room_messages_path(@room),
        params: { message: { body: "Hello!" } }
    end
  end
end
```

## System Tests with Action Cable

```ruby
class ChatSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:active_user)
    @room = rooms(:general)
    sign_in @user
  end

  test "receives messages in real-time" do
    visit room_path(@room)

    # Simulate another user sending a message
    Message.create!(room: @room, user: users(:other_user), body: "Hello from other!")

    # Assert it appears without page refresh
    assert_selector "[data-message]", text: "Hello from other!", wait: 5
  end
end
```

**Note:** System tests need the `async` or `test` adapter and may require `Capybara.server = :puma` for WebSocket support.
