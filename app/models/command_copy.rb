# Counts copies of a theme's install command on the site: one row per theme per day, no identity.
class CommandCopy < ApplicationRecord
  validates :slug, :day, presence: true

  def self.record(slug, day: Date.current)
    upsert({ slug: slug, day: day, count: 1, created_at: Time.current, updated_at: Time.current },
           unique_by: [ :slug, :day ], on_duplicate: Arel.sql("count = command_copies.count + 1, updated_at = excluded.updated_at"))
    Engagement.expire
  end

  def self.total_for(slug) = where(slug: slug).sum(:count)
end
