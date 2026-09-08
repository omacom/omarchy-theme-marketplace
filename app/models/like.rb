class Like < ApplicationRecord
  belongs_to :user
  validates :slug, presence: true, uniqueness: { scope: :user_id }

  after_commit { Engagement.expire }
end
