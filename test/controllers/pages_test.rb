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
    assert_select "header nav a", text: "Guide", count: 0
    assert_select "header a[href=?]", guide_path, text: "Submit a theme"
    assert_select "#submit", count: 0
  end

  test "home shows a top authors leaderboard in the stats section" do
    get root_path
    assert_response :success
    assert_select "#figures" do
      assert_select "[data-slot=card]", minimum: 1
      assert_select "ol li", minimum: 1
      assert_select "ol li:first-of-type a[href=?]", author_path("HANCORE-linux")
    end
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
    assert_select "figure img[alt='Nujabes theme preview'][width='1200']"
    assert_select "dl dd a[href=?]", author_path("HalmyLyseas"), text: "HalmyLyseas"
    assert_select "dl dd a.font-mono[href*='/commit/']"
    assert_select "dl dd time"
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

  test "guide renders as one page with the submission flow" do
    get guide_path
    assert_response :success
    assert_select "article h1", "Guide"
    assert_select "article h2#make-a-theme"
    assert_select "article h2#submit-a-theme"
    assert_select "article h2#what-gets-checked"
    assert_select "article h2#install-update-and-remove"
    assert_select "article a[href=?]", Rails.configuration.x.submit_url
    assert_select "nav[aria-label='On this page'] a[href='#submit-a-theme']"
    get guide_page_path("nope")
    assert_response :not_found
    get guide_page_path("api") # hidden for now
    assert_response :not_found
    get guide_page_path("making-a-theme") # merged into the single page now
    assert_response :not_found
  end
end
