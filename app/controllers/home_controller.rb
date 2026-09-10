class HomeController < ApplicationController
  TOP_ARTISTS = 5

  def index
    @query = ThemeQuery.new(catalog, params)
    @stats = build_stats
    @top_artists = build_top_artists
  end

  private

  def build_stats
    total = catalog.size
    updated_recently = catalog.themes.count { |t| t.pushed_at && t.pushed_at > 30.days.ago }
    artist_counts = catalog.themes.group_by(&:artist_login).transform_values(&:size)
    prolific = artist_counts.count { |_, n| n > 1 }
    dark = catalog.dark.size
    light = catalog.light.size
    pct = ->(n) { total.zero? ? 0 : (n * 100.0 / total).round }

    [
      { label: "Themes published", value: total, icon: :mark,
        detail: "#{updated_recently} updated in the last 30d" },
      { label: "Theme artists", value: artist_counts.size, icon: :github,
        detail: "#{prolific} with more than one theme" },
      { label: "Dark themes", value: dark, icon: :moon, pct: pct.(dark),
        detail: "#{pct.(dark)}% of the catalog" },
      { label: "Light themes", value: light, icon: :sun, pct: pct.(light),
        detail: "#{pct.(light)}% of the catalog" }
    ]
  end

  def build_top_artists
    catalog.artist_stats.first(TOP_ARTISTS)
  end
end
