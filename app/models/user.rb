class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :likes, dependent: :destroy

  validates :github_id, :login, presence: true

  # Upsert from the OmniAuth auth hash; login/name/avatar follow GitHub on every sign-in.
  def self.from_github(auth)
    info = auth.info || {}
    user = find_or_initialize_by(github_id: auth.uid.to_i)
    user.login = info.nickname
    user.name = info.name.presence
    user.avatar_url = info.image.presence
    user.save!
    user
  end

  def profile_url = "https://github.com/#{login}"
  def liked?(slug) = liked_slugs.include?(slug)
  def liked_slugs = @liked_slugs ||= likes.pluck(:slug).to_set
end
