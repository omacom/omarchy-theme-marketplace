class HomeController < ApplicationController
  def index
    @query = ThemeQuery.new(catalog, params)
    @stats = build_stats
  end

  private

  def build_stats
    total = catalog.size
    updated_recently = catalog.themes.count { |t| t.pushed_at && t.pushed_at > 30.days.ago }
    author_counts = catalog.themes.group_by(&:author_login).transform_values(&:size)
    prolific = author_counts.count { |_, n| n > 1 }
    dark = catalog.dark.size
    light = catalog.light.size
    pct = ->(n) { total.zero? ? 0 : (n * 100.0 / total).round }

    [
      { label: "Themes published", value: total, icon: :mark,
        detail: "#{updated_recently} updated in the last 30 days" },
      { label: "Theme authors", value: author_counts.size, icon: :github,
        detail: "#{prolific} with more than one theme" },
      { label: "Dark themes", value: dark, icon: :moon, pct: pct.(dark),
        detail: "#{pct.(dark)}% of the catalog" },
      { label: "Light themes", value: light, icon: :sun, pct: pct.(light),
        detail: "#{pct.(light)}% of the catalog" }
    ]
  end
end
