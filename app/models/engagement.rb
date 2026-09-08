# Likes and install-command copies per theme, read from the database and cached briefly so the
# catalog (a plain value object) can carry them without a query per card.
module Engagement
  CACHE_KEY = "engagement:v1"
  TTL = 1.minute
  TRENDING_WINDOW = 7.days

  Stats = Struct.new(:likes, :copies, :trending, keyword_init: true)
  NONE = Stats.new(likes: 0, copies: 0, trending: 0).freeze

  module_function

  def for(slug) = all.fetch(slug, NONE)

  def all
    Rails.cache.fetch(CACHE_KEY, expires_in: TTL) { compute }
  end

  def expire
    Rails.cache.delete(CACHE_KEY)
  end

  def compute
    since = TRENDING_WINDOW.ago
    likes = Like.group(:slug).count
    copies = CommandCopy.group(:slug).sum(:count)
    recent_likes = Like.where(created_at: since..).group(:slug).count
    recent_copies = CommandCopy.where(day: since.to_date..).group(:slug).sum(:count)

    (likes.keys | copies.keys).to_h do |slug|
      [ slug, Stats.new(
        likes: likes.fetch(slug, 0),
        copies: copies.fetch(slug, 0),
        # A like is a stronger signal than a copied command.
        trending: recent_likes.fetch(slug, 0) * 3 + recent_copies.fetch(slug, 0)
      ) ]
    end
  end
end
