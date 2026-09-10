class HomeController < ApplicationController
  TOP_AUTHORS = 5

  def index
    @query = ThemeQuery.new(catalog, params)
    @stats = build_stats
    @top_authors = build_top_authors
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

  # Ranked by themes published, ties broken by total stars across those themes.
  def build_top_authors
    catalog.themes
      .group_by(&:author_login)
      .map { |login, themes|
        { login: login, url: themes.first.author_url, count: themes.size, stars: themes.sum(&:stars) }
      }
      .sort_by { |a| [ -a[:count], -a[:stars], a[:login].downcase ] }
      .first(TOP_AUTHORS)
  end
end
