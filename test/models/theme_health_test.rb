require "test_helper"

class ThemeHealthTest < ActiveSupport::TestCase
  setup { @data = JSON.parse(File.read(Rails.root.join("test/fixtures/theme_health.json"))) }

  def health(data = @data, commit: @data["commit"]) = ThemeHealth.new(data, commit: commit)

  test "reads the registry exporter fixture and freezes a private copy" do
    report = health
    assert report.graded?
    assert_equal "A", report.grade_label
    assert_equal 5, report.categories.size
    assert_equal 22, report.count("pass")
    assert report.data.frozen?
    assert report.findings.first.frozen?
    @data["grade"] = "F"
    assert_equal "A", report.grade_label
  end

  test "provisional reports keep their asterisk and limited categories" do
    @data["state"] = "provisional"
    @data["categories"].last["state"] = "not-checked"
    @data["categories"].last["grade"] = nil
    report = health
    assert_equal "A*", report.grade_label
    assert report.provisional?
  end

  test "never attaches an old grade to a new theme commit" do
    report = health(commit: "2" * 40)
    assert report.outdated?
    assert_nil report.grade_label
    refute report.graded?
  end

  test "ungraded and absent reports are not failures" do
    assert_equal "not-checked", health(nil).state
    @data["state"] = "not-graded"
    @data["grade"] = nil
    assert health.current?
    assert_nil health.grade_label
  end

  test "unknown schema malformed dates and duplicate categories fail open" do
    [ @data.merge("schema_version" => 2), @data.merge("checked_at" => false),
      @data.merge("categories" => [ @data["categories"].first ] * 5), @data.merge("state" => "not-graded") ].each do |value|
      refute health(value).available?
    end
  end

  test "rejects malicious colors and unsupported measurement values" do
    @data["findings"].first["measurement"] = { "kind" => "contrast", "value" => 2.5, "target" => 4.5, "foreground" => "red; background: url(evil)" }
    refute health.available?
    @data["findings"].first["measurement"]["foreground"] = "#ffffff"
    @data["findings"].first["measurement"]["value"] = Float::INFINITY
    refute health.available?
  end

  test "unknown fields and oversized reports are not published as JSON" do
    refute health(@data.merge("watchedPaths" => [ "/private/path" ])).available?
    refute health(@data.merge("summary" => "x" * 100_000)).available?
  end
end
