require "test_helper"

class ThemeQueryTest < ActiveSupport::TestCase
  setup { @catalog = Catalog.new(Catalog.snapshot) }

  def query(**params)
    ThemeQuery.new(@catalog, ActionController::Parameters.new(params))
  end

  test "defaults to all when nothing is featured" do
    q = query
    assert_equal(@catalog.any_featured? ? "featured" : "all", q.filter)
  end

  test "filters by mode and hue" do
    assert query(filter: "dark").results.all?(&:dark?)
    assert query(filter: "light").results.all?(&:light?)
    assert query(filter: "blue").results.all? { |t| t.hue == "blue" }
  end

  test "ignores unknown filters" do
    assert_equal query.filter, query(filter: "<script>").filter
  end

  test "searches name and artist" do
    assert query(filter: "all", q: "nuja").results.map(&:slug).include?("nujabes")
    assert query(filter: "all", q: "halmy").results.map(&:slug).include?("nujabes")
    assert_empty query(filter: "all", q: "zzzzzzzz").results
  end

  test "a search widens the featured filter to all but keeps mode and hue filters" do
    assert_equal "all", query(q: "nuja").filter
    assert_equal "all", query(filter: "featured", q: "nuja").filter
    assert_includes query(filter: "featured", q: "nuja").results.map(&:slug), "nujabes"
    assert_equal "dark", query(filter: "dark", q: "nuja").filter
    assert_equal query.filter, query(q: "  ").filter
  end

  test "sorts" do
    names = query(filter: "all").results.map { |t| t.name.downcase }
    assert_equal names.sort, names
    stars = query(filter: "all", sort: "stars").results.map(&:stars)
    assert_equal stars.sort.reverse, stars
  end

  test "paginates 12 per page and clamps the page" do
    q = query(filter: "all", page: 2)
    assert q.paginated?
    assert_equal 12, q.page_results.size
    assert_equal q.total_pages, query(filter: "all", page: 999).current_page
  end

  test "page items include ellipses on long lists" do
    q = query(filter: "all", page: 5)
    items = q.page_items
    assert_equal 1, items.first
    assert_equal q.total_pages, items.last
    assert_includes items, :ellipsis if q.total_pages > 7
  end

  test "params_for drops defaults" do
    q = query(filter: "dark", q: "x", sort: "stars", page: 3)
    assert_equal({ filter: "dark", q: "x", sort: "stars" }, q.params_for)
    assert_equal({ filter: "dark", q: "x", sort: "stars", page: 2 }, q.params_for(page: 2))
  end

  test "searches descriptions" do
    theme = @catalog.themes.find { |t| t.description.to_s.split.any? { |w| w.size > 6 } }
    word = theme.description.split.find { |w| w.size > 6 }.downcase.delete("^a-z")
    assert_includes query(filter: "all", q: word).results, theme
  end

  test "finds themes by colour, closest first" do
    theme = @catalog.find("nujabes")
    results = query(color: theme.accent).results
    assert_equal theme, results.first, "its own accent is the closest match"
    target = Color.oklab(theme.accent)
    distances = results.map { |t| t.color_distance(target) }
    assert_equal distances.sort, distances
  end

  test "a colour search widens featured to all and keeps other filters" do
    q = query(filter: "featured", color: "#ff69b4")
    assert_equal "all", q.filter
    assert query(filter: "light", color: "#ff69b4").results.all?(&:light?)
    assert_equal "#ff69b4", q.params_for[:color]
  end

  test "a rare colour still finds the closest few" do
    assert_operator query(filter: "all", color: "#00ff00").total, :>=, ThemeQuery::COLOR_MIN_RESULTS
  end

  test "ignores a malformed colour" do
    assert_nil query(color: "red; drop").color
    assert_nil query(color: "#12345").color
    assert_equal "#abcdef", query(color: "ABCDEF").color
  end
end
