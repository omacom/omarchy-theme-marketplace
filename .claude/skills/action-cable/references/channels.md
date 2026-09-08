# Channel Patterns

## Basic Channel with Parameter Validation

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find_by(id: params[:room_id])

    if room && room.accessible_by?(current_user)
      stream_for room
    else
      reject
    end
  end

  def unsubscribed
    # Clean up: remove from online users, release locks, etc.
  end

  def speak(data)
    room = Room.find(params[:room_id])
    message = room.messages.create!(
      user: current_user,
      body: data["body"]
    )
    # Broadcasting happens in model callback or job
  end
end
```

**Always validate params and authorize access in `subscribed`.** Never trust client-supplied params without verification.

## Channel with Callbacks

```ruby
class GameChannel < ApplicationCable::Channel
  before_subscribe :verify_game_access
  after_subscribe :announce_player_joined

  def subscribed
    @game = Game.find(params[:game_id])
    stream_for @game
  end

  def unsubscribed
    announce_player_left
  end

  private
    def verify_game_access
      game = Game.find_by(id: params[:game_id])
      reject unless game&.player?(current_user)
    end

    def announce_player_joined
      GameChannel.broadcast_to(@game, {
        type: "player_joined",
        player: current_user.display_name
      })
    end

    def announce_player_left
      game = Game.find_by(id: params[:game_id])
      return unless game

      GameChannel.broadcast_to(game, {
        type: "player_left",
        player: current_user.display_name
      })
    end
end
```

## Multiple Streams Per Channel

```ruby
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard_global"
    stream_from "dashboard_team_#{current_user.team_id}"
    stream_for current_user  # Personal notifications too
  end
end
```

## Dynamic Subscribe/Unsubscribe

```ruby
class RoomChannel < ApplicationCable::Channel
  def subscribed
    # Start with no streams — client will call follow/unfollow
  end

  def follow(data)
    room = Room.find(data["room_id"])
    stream_for room if room.accessible_by?(current_user)
  end

  def unfollow(data)
    room = Room.find(data["room_id"])
    stop_stream_for room
  end
end
```
