# Broadcasting Patterns

## From Models (with Background Job)

```ruby
class Message < ApplicationRecord
  belongs_to :room
  belongs_to :user

  after_create_commit :broadcast_message

  private
    def broadcast_message
      MessageBroadcastJob.perform_later(self)
    end
end
```

```ruby
class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    html = ApplicationController.renderer.render(
      partial: "messages/message",
      locals: { message: message }
    )

    ChatChannel.broadcast_to(message.room, {
      type: "new_message",
      html: html,
      message_id: message.id,
      sent_by: message.user.display_name
    })
  end
end
```

## From Controllers

```ruby
class MessagesController < ApplicationController
  def create
    @message = @room.messages.create!(message_params.merge(user: current_user))

    # Broadcast inline (simple cases)
    ActionCable.server.broadcast("chat_#{@room.id}", {
      html: render_to_string(partial: "messages/message", locals: { message: @message })
    })

    head :created
  end
end
```

## Targeted Broadcasts

```ruby
# Broadcast to a specific user
NotificationsChannel.broadcast_to(user, {
  title: "New follower",
  body: "#{follower.name} started following you"
})

# Broadcast to all users in a team
team.users.each do |user|
  NotificationsChannel.broadcast_to(user, { ... })
end

# Better: use a team stream
ActionCable.server.broadcast("team_#{team.id}", { ... })
```

## Conditional Broadcasting

```ruby
class Comment < ApplicationRecord
  after_create_commit :broadcast_if_public

  private
    def broadcast_if_public
      return unless post.public?

      CommentsChannel.broadcast_to(post, {
        html: ApplicationController.renderer.render(
          partial: "comments/comment",
          locals: { comment: self }
        )
      })
    end
end
```
