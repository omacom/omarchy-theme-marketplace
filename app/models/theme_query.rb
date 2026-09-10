# Filtering, searching, sorting and paging over the catalog, driven by URL params so
# every gallery state is shareable.
class ThemeQuery
  PER_PAGE = 12
  FILTERS = %w[featured all dark light].freeze
  # Spectral order, matching the registry's hue buckets.
  HUES = %w[red orange yellow green teal blue purple pink gray].freeze
  # "likes" => "Most liked" returns with the engagement feature (plan.md).
  SORTS = { "name" => "Name", "new" => "Newest", "trending" => "Trending", "stars" => "Stars" }.freeze

  HUE_SWATCHES = {
    "red" => "#f7768e", "orange" => "#ff9e64", "yellow" => "#e0af68", "green" => "#9ece6a",
    "teal" => "#2ac3de", "blue" => "#7aa2f7", "purple" => "#bb9af7", "pink" => "#f5bde6",
    "gray" => "#9099b2"
  }.freeze

  attr_reader :catalog, :filter, :query, :sort, :page

  def initialize(catalog, params)
    @catalog = catalog
    @filter = normalize_filter(params[:filter])
    @query = params[:q].to_s.strip
    @sort = SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : "name"
    @page = [ params[:page].to_i, 1 ].max
  end

  def default_filter
    catalog.any_featured? ? "featured" : "all"
  end

  def results
    @results ||= sort_themes(filter_themes(catalog.themes))
  end

  def total = results.size
  def total_pages = [ (total.to_f / PER_PAGE).ceil, 1 ].max
  def paginated? = total > PER_PAGE
  def page_results = results.slice((current_page - 1) * PER_PAGE, PER_PAGE) || []
  def current_page = [ page, total_pages ].min

  # URL params for a link that keeps the current state and changes one key.
  def params_for(**changes)
    base = { filter: filter, q: query.presence, sort: (sort unless sort == "name"), page: nil }
    base[:filter] = nil if base[:filter] == default_filter
    base.merge(changes).compact
  end

  # bits-ui-style page list with one sibling on each side and ellipses.
  def page_items
    last = total_pages
    return (1..last).to_a if last <= 7
    cur = current_page
    items = [ 1 ]
    left = [ cur - 1, 2 ].max
    right = [ cur + 1, last - 1 ].min
    left = 2 if cur <= 3
    right = last - 1 if cur >= last - 2
    items << :ellipsis if left > 2
    items.concat((left..right).to_a)
    items << :ellipsis if right < last - 1
    items << last
  end

  private

  def normalize_filter(raw)
    raw = raw.to_s
    return raw if FILTERS.include?(raw) || HUES.include?(raw)
    default_filter
  end

  def filter_themes(themes)
    themes = case filter
    when "featured" then themes.select(&:featured?)
    when "all" then themes
    when "dark", "light" then themes.select { |t| t.mode == filter }
    else themes.select { |t| t.hue == filter }
    end
    return themes if query.blank?
    q = query.downcase
    themes.select { |t| t.name.downcase.include?(q) || t.artist_login.to_s.downcase.include?(q) || t.tags.any? { |tag| tag.include?(q) } }
  end

  def sort_themes(themes)
    case sort
    when "new" then themes.sort_by { |t| [ -(t.added_at&.jd || 0), t.name.downcase ] }
    when "stars" then themes.sort_by { |t| [ -t.stars, t.name.downcase ] }
    when "likes" then themes.sort_by { |t| [ -t.likes, -t.copies, t.name.downcase ] }
    when "trending" then themes.sort_by { |t| [ -t.trending, -t.likes, -t.copies, t.name.downcase ] }
    else themes.sort_by { |t| t.name.downcase }
    end
  end
end
