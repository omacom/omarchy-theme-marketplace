require "test_helper"

class PaletteHelperTest < ActionView::TestCase
  include PaletteHelper

  def theme_with(colors)
    Theme.new("slug" => "x", "name" => "X", "colors" => colors)
  end

  test "emits required colours and derives the rest like omarchy-theme-color" do
    style = palette_style(theme_with("accent" => "#ff0000", "background" => "#000000", "foreground" => "#ffffff"))
    assert_includes style, "--p-accent: #ff0000"
    assert_includes style, "--p-bright-red: color-mix(in srgb, var(--p-red) 80%, white)"
    assert_includes style, "--p-dark-background: color-mix(in srgb, var(--p-background) 75%, black)"
    assert_includes style, "--p-muted: var(--p-dark-foreground)"
    assert_includes style, "--p-dark-foreground: var(--p-foreground)"
    assert_includes style, "--p-orange: var(--p-yellow)"
    assert_includes style, "--p-inactive-border: rgba(89, 89, 89, 0.67)"
  end

  test "uses optional colours when present" do
    style = palette_style(theme_with("muted" => "#808080", "bright_red" => "#ff5555", "orange" => "#ff9900"))
    assert_includes style, "--p-muted: #808080"
    assert_includes style, "--p-bright-red: #ff5555"
    assert_includes style, "--p-orange: #ff9900"
    refute_includes style, "--p-bright-red: color-mix"
  end

  test "theme primary uses the accent, nudged to 3:1 against each mode's background" do
    style = theme_primary_style(theme_with("accent" => "#7aa2f7"))
    assert_match(/--primary: light-dark\(#[0-9a-f]{6}, #7aa2f7\)/, style)
    refute_includes style, "light-dark(#7aa2f7,", "a light accent is darkened for light mode"
    assert_includes style, "--primary-foreground: light-dark(#0a0a0a, #0a0a0a)"
    assert_match(/--ring: light-dark\(/, style)

    dark_accent = theme_primary_style(theme_with("accent" => "#1a1a2e"))
    assert_match(/--primary: light-dark\(#1a1a2e, #[0-9a-f]{6}\)/, dark_accent)
    refute_includes dark_accent, ", #1a1a2e)", "a dark accent is lightened for dark mode"
    assert_match(/--primary-foreground: light-dark\(#fafafa, /, dark_accent)

    assert_includes theme_primary_style(theme_with("accent" => "#f00")), "light-dark(#ff0000, #ff0000)"
  end

  test "theme primary is skipped when the accent is not a hex colour" do
    assert_nil theme_primary_style(theme_with("accent" => "url(javascript:alert(1))"))
    assert_nil theme_primary_style(theme_with({}))
  end

  test "ignores values that are not hex colours" do
    style = palette_style(theme_with("accent" => "url(javascript:alert(1))", "muted" => "red"))
    refute_includes style, "javascript"
    refute_includes style, "--p-muted: red"
    assert_includes style, "--p-muted: var(--p-dark-foreground)"
  end
end
