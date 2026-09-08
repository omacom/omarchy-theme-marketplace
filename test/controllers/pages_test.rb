require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "home renders the gallery from the catalog" do
    get root_path
    assert_response :success
    assert_select "h1, p", /Community Themes/
    assert_select "turbo-frame#gallery"
    assert_select "[data-slot=card]", minimum: 1
    assert_select "[data-slot=card] a[title='GitHub stars']", minimum: 1
    assert_select "footer"
    assert_select "header nav a[href=?]", docs_path, text: "Docs"
  end

  test "home filters, searches and pages via params" do
    get root_path(filter: "light")
    assert_response :success
    assert_select "a[aria-pressed=true]", text: "Light"
    assert_select "a[aria-pressed=false][href*='filter=dark']", text: "Dark"

    get root_path(filter: "all", q: "nujabes")
    assert_response :success
    assert_select "a[href=?]", theme_path("nujabes")

    get root_path(filter: "all", page: 2)
    assert_response :success
    assert_select "nav[aria-label=pagination] a[aria-current=page]", text: "2"
    assert_select "nav[aria-label=pagination] a[href*='page=3']"
  end

  test "home answers turbo frame requests with the frame" do
    get root_path(filter: "dark"), headers: { "Turbo-Frame" => "gallery" }
    assert_response :success
    assert_select "turbo-frame#gallery"
  end

  test "theme page shows install command, palette and og tags" do
    get theme_path("nujabes")
    assert_response :success
    assert_select "h1", "Nujabes"
    assert_select "code", /omarchy theme install/
    assert_select "[data-controller=copy]", minimum: 2
    assert_select "meta[property='og:image']"
    assert_select "a[href=?]", author_path("HalmyLyseas")
  end

  test "unknown theme is a 404" do
    get theme_path("does-not-exist")
    assert_response :not_found
  end

  test "author page lists themes" do
    get author_path("HalmyLyseas")
    assert_response :success
    assert_select "h1", /HalmyLyseas/
    assert_select "[data-slot=card]", minimum: 1
    get author_path("nobody-here-xyz")
    assert_response :not_found
  end

  test "docs render markdown" do
    get docs_path
    assert_response :success
    assert_select "article h1", "Documentation"
    get doc_path("validation")
    assert_response :success
    assert_select "article h2", minimum: 2
    get doc_path("nope")
    assert_response :not_found
    get doc_path("api") # hidden for now
    assert_response :not_found
  end
end
