require "test_helper"

class ThemeHealthPagesTest < ActionDispatch::IntegrationTest
  setup do
    @current = Catalog.method(:current)
    @health = JSON.parse(File.read(Rails.root.join("test/fixtures/theme_health.json")))
    @snapshot = Catalog.snapshot
    @entry = @snapshot["themes"].first
    @health["commit"] = @entry["commit"]
  end

  teardown { Catalog.define_singleton_method(:current, @current) }

  test "muted grade and clipboard sit beside stars and open the whole page from Turbo" do
    install_report
    get root_path(filter: "all")
    assert_response :success
    assert_select "[data-theme-health-grade]", text: "A", minimum: 1
    assert_select "a[data-theme-health-grade][data-turbo-frame='_top'][href$='#theme-health'].text-muted-foreground" do
      assert_select "svg.size-4[aria-hidden=true]"
    end
    assert_select "[data-slot=card] span[title='GitHub stars']", minimum: 1
    get theme_path(@entry["slug"])
    assert_select "#theme-health [data-health-category]", count: 5
    assert_select "#theme-health", text: /All checked areas look healthy/
    assert_select "#theme-health time"
    assert_select "#theme-health a[href=?]", theme_health_path(@entry["slug"])
  end

  test "provisional data has an explicit limitation and asterisk" do
    @health["state"] = "provisional"
    @health["categories"].last["state"] = "not-checked"
    @health["categories"].last["grade"] = nil
    install_report
    get theme_path(@entry["slug"])
    assert_select "[data-theme-health-grade]", text: "A*"
    assert_select "#theme-health", text: /Unmeasured checks are not passes/
  end

  test "stale grades disappear without removing the theme or its installation" do
    @health["commit"] = "2" * 40
    @health["checked_at"] = "2026-10-22T10:16:46-07:00"
    install_report
    get theme_path(@entry["slug"])
    assert_response :success
    assert_select "[data-theme-health-grade]", count: 0
    assert_select "#theme-health", text: /older commit/
    assert_select "code", text: @entry["install"]
    get theme_health_path(@entry["slug"])
    assert_response :not_found
  end

  test "missing or malformed reports remain ungraded and installable" do
    @health = { "grade" => "A", "schema_version" => 999 }
    install_report
    get theme_path(@entry["slug"])
    assert_response :success
    assert_select "[data-theme-health-grade]", count: 0
    assert_select "#theme-health h3", "Not checked yet."
    assert_select "code", text: @entry["install"]
  end

  test "findings are escaped and scalar measurement colors are validated" do
    @health["summary"] = "<script>notExecutable()</script>"
    finding = @health["findings"].find { |f| f["rule_id"] == "readability.foundation" }
    finding["severity"] = "failure"
    finding["measurement"] = { "kind" => "contrast", "value" => 2.25, "target" => 4.5, "foreground" => "#aaaaaa", "background" => "#666666" }
    install_report
    get theme_path(@entry["slug"])
    assert_select "#theme-health script", count: 0
    assert_includes response.body, "&lt;script&gt;notExecutable()&lt;/script&gt;"
    assert_select "#theme-health [style*='color: #aaaaaa']"
    assert_select "#theme-health", text: /2\.25/
  end

  test "offset timestamps render in UTC without mutating the shared frozen report" do
    [ "2026-10-22T17:16:46+00:00", "2026-10-23T01:16:46+08:00",
      "2026-10-22T22:46:46+05:30", "2026-10-22T10:16:46-07:00" ].each do |timestamp|
      @health["checked_at"] = timestamp
      install_report
      checked_at = Catalog.current.find!(@entry["slug"]).health.checked_at
      original_offset = checked_at.utc_offset
      assert checked_at.frozen?
      2.times do
        get theme_path(@entry["slug"])
        assert_response :success
        assert_select "#theme-health time", text: "October 22, 2026 17:16 UTC"
        assert_equal original_offset, checked_at.utc_offset
      end
      get theme_health_path(@entry["slug"])
      assert_response :success
      assert_equal timestamp, response.parsed_body["checked_at"]
    end
  end

  test "passing checks keep their evidence in nested disclosures" do
    install_report
    get theme_path(@entry["slug"])
    assert_response :success
    assert_select "[data-health-category=readability] details[data-health-passes]:not([open])" do
      assert_select "summary", text: "10 checks meet targets"
      assert_select "li > details[data-health-rule]", count: 10
      assert_select "details[data-health-rule='readability.foundation']:not([open])" do
        assert_select "summary", text: /Terminal text\s+Meets target/
        assert_select "p", text: "Foundational text contrast"
        assert_select "p", text: "Resolved colors"
        assert_select "dl dt", text: "Measured"
        assert_select "dl dd", text: "16.618:1"
        assert_select "dl dt", text: "Target"
        assert_select "dl dd", text: "4.5:1"
        assert_select "[style*='color: #f0f2f4']"
        assert_select "p span", text: "What could improve"
        assert_select "p span", text: "No change needed."
        assert_select "li", text: "colors.toml → foreground"
        assert_select "li", text: "colors.toml → background"
      end
    end
  end

  test "JSON is exactly the current versioned public report and has no audit side effects" do
    install_report
    get theme_health_path(@entry["slug"])
    assert_response :success
    assert_equal @health, response.parsed_body
    assert_equal 1, response.parsed_body["schema_version"]
    refute response.parsed_body.key?("themePath")
  end

  test "health JSON preserves dotted theme slugs" do
    @entry["slug"] = "example.v2"
    install_report
    assert_equal "/themes/example.v2/health", theme_health_path(@entry["slug"])
    get theme_health_path(@entry["slug"])
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal @health, response.parsed_body
    get theme_path(@entry["slug"])
    assert_response :success
    assert_select "#theme-health a[href=?]", theme_health_path(@entry["slug"])
  end

  test "missing and unsupported health JSON never invents a report" do
    [ nil, { "schema_version" => 999 } ].each do |data|
      @health = data
      install_report
      get theme_health_path(@entry["slug"])
      assert_response :not_found
    end
    get theme_health_path("does-not-exist")
    assert_response :not_found
  end

  test "current ungraded reports retain their limitations and JSON without a letter" do
    @health["state"] = "not-graded"
    @health["grade"] = nil
    install_report
    get theme_path(@entry["slug"])
    assert_response :success
    assert_select "[data-theme-health-grade]", count: 0
    assert_select "#theme-health h3", text: "No grade could be measured."
    assert_select "#theme-health [data-health-category]", count: 5
    get theme_health_path(@entry["slug"])
    assert_response :success
    assert_equal @health, response.parsed_body
  end

  test "adding reports never changes catalog ordering" do
    baseline = ThemeQuery.new(Catalog.new(@snapshot), {}).results.map(&:slug)
    install_report
    assert_equal baseline, ThemeQuery.new(Catalog.current, {}).results.map(&:slug)
  end

  private
    def install_report
      @entry["health"] = @health
      catalog = Catalog.new(@snapshot)
      Catalog.define_singleton_method(:current) { catalog }
    end
end
