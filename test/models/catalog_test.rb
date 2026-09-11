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
    assert_match(/\Aomarchy theme install https:\/\/github\.com\//, theme.install)
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
    assert_raises(ActiveRecord::RecordNotFound) { @catalog.find!("nope") }
  end

  private
    def theme_added(date) = Theme.new("slug" => "x", "added_at" => date.iso8601)
end
