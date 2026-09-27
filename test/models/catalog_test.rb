require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  setup { @catalog = Catalog.new(Catalog.snapshot) }

  test "loads the snapshot" do
    assert_operator @catalog.size, :>, 50
    assert_equal 1, @catalog.schema_version
  end

  test "finds a theme by slug and exposes derived fields" do
    theme = @catalog.find("nujabes")
    assert_equal "Nujabes", theme.name
    assert_equal "HalmyLyseas", theme.artist_login
    assert_includes %w[dark light], theme.mode
    assert_match(/\A#[0-9a-f]{6}\z/, theme.accent)
    assert_equal "omarchy theme install nujabes", theme.install
    assert_equal 7, theme.short_commit.length
  end

  # Bulk imports can carry recent added_at dates, so the snapshot itself may hold
  # new themes; what must hold is the rule that decides which ones count. The clock
  # is pinned so the age window and the import cutoff are exercised independently.
  test "new? covers submissions inside the window" do
    travel_to Theme::IMPORT_DATE + 60 do
      assert theme_added(Date.current).new?
      assert theme_added(Date.current - Theme::NEW_FOR_DAYS + 1).new?
      refute theme_added(Date.current - Theme::NEW_FOR_DAYS - 1).new?
      refute Theme.new("slug" => "x").new?
    end
  end

  test "new? never covers the seeded import, however recent" do
    travel_to Theme::IMPORT_DATE + 3 do
      refute theme_added(Theme::IMPORT_DATE).new?
      refute theme_added(Theme::IMPORT_DATE - 1).new?
      assert theme_added(Theme::IMPORT_DATE + 1).new?
    end
  end

  test "artists are grouped case-insensitively" do
    theme = @catalog.themes.first
    assert_includes @catalog.by_artist(theme.artist_login.upcase), theme
  end

  test "find! raises for unknown slugs" do
    assert_raises(NotFound) { @catalog.find!("nope") }
  end

  private
    def theme_added(date) = Theme.new("slug" => "x", "added_at" => date.iso8601)

  # The CDN is faked by swapping fetch_remote, so each test sees a CDN that works, then fails.
  class Fallback < ActiveSupport::TestCase
    setup do
      @url = Rails.configuration.x.catalog_url
      @fetch = Catalog.method(:fetch_remote)
      Rails.configuration.x.catalog_url = "https://cdn.test/v1/catalog.json"
      Catalog.instance_variable_set(:@last_fetched, nil)
    end

    teardown do
      Rails.configuration.x.catalog_url = @url
      Catalog.define_singleton_method(:fetch_remote, @fetch)
      Catalog.instance_variable_set(:@last_fetched, nil)
    end

    def cdn(data) = Catalog.define_singleton_method(:fetch_remote) { data }

    test "serves the last fetched catalog while the CDN is down" do
      fetched = Catalog.snapshot.merge("generated_at" => "2026-10-01T00:00:00Z")
      fetched["themes"] = fetched["themes"].first(3)
      cdn(fetched)
      assert_equal 3, Catalog.current.size

      cdn(nil)
      assert_equal 3, Catalog.current.size, "not the older snapshot"
      assert_equal Time.iso8601("2026-10-01T00:00:00Z"), Catalog.current.generated_at
    end

    test "falls back to the snapshot only before anything was fetched" do
      cdn(nil)
      assert_equal Catalog.new(Catalog.snapshot).size, Catalog.current.size
    end
  end
end
