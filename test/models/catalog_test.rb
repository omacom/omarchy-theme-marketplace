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
    assert_equal "HalmyLyseas", theme.author_login
    assert_includes %w[dark light], theme.mode
    assert_match(/\A#[0-9a-f]{6}\z/, theme.accent)
    assert_match(/\Aomarchy theme install https:\/\/github\.com\//, theme.install)
    assert_equal 7, theme.short_commit.length
  end

  test "imported themes are not new" do
    refute @catalog.themes.any?(&:new?)
  end

  test "authors are grouped case-insensitively" do
    theme = @catalog.themes.first
    assert_includes @catalog.by_author(theme.author_login.upcase), theme
  end

  test "find! raises for unknown slugs" do
    assert_raises(ActiveRecord::RecordNotFound) { @catalog.find!("nope") }
  end
end
