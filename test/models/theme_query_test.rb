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

  test "searches name and author" do
    assert query(filter: "all", q: "nuja").results.map(&:slug).include?("nujabes")
    assert query(filter: "all", q: "halmy").results.map(&:slug).include?("nujabes")
    assert_empty query(filter: "all", q: "zzzzzzzz").results
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
end
