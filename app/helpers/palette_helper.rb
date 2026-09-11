# Exposes a theme's palette as CSS custom properties (--p-*) for the desktop preview.
# Only the nine required keys are guaranteed by the registry; the rest are derived the way
# `omarchy-theme-color` derives them, so the mock matches what the theme looks like installed.
# Anything that is not a hex colour is ignored (the values come from an external catalog).
module PaletteHelper
  HEX = /\A#(?:\h{3}|\h{4}|\h{6}|\h{8})\z/

  REQUIRED = %w[accent background foreground red yellow green cyan blue magenta].freeze

  # key => fallback expression, in Omarchy's derivation order (later ones may reference earlier vars).
  DERIVED = {
    "bright_red" => "color-mix(in srgb, var(--p-red) 80%, white)",
    "bright_yellow" => "color-mix(in srgb, var(--p-yellow) 80%, white)",
    "bright_green" => "color-mix(in srgb, var(--p-green) 80%, white)",
    "bright_cyan" => "color-mix(in srgb, var(--p-cyan) 80%, white)",
    "bright_blue" => "color-mix(in srgb, var(--p-blue) 80%, white)",
    "bright_magenta" => "color-mix(in srgb, var(--p-magenta) 80%, white)",
    "bright_foreground" => "var(--p-foreground)",
    "dark_foreground" => "var(--p-foreground)",
    "light_foreground" => "var(--p-foreground)",
    "dark_background" => "color-mix(in srgb, var(--p-background) 75%, black)",
    "darker_background" => "color-mix(in srgb, var(--p-background) 50%, black)",
    "lighter_background" => "var(--p-background)",
    "muted" => "var(--p-dark-foreground)",
    # Omarchy falls back to muted, then background; a slightly tinted mix keeps the mock legible.
    "selection" => "color-mix(in oklab, var(--p-foreground) 15%, var(--p-background))",
    "orange" => "var(--p-yellow)",
    "brown" => "color-mix(in srgb, var(--p-orange) 50%, black)",
    "cursor" => "var(--p-bright-foreground)"
  }.freeze

  # Blends the generated Neovim colorscheme and Hyprland use; not palette keys.
  EXTRA = {
    "cursorline" => "color-mix(in oklab, var(--p-foreground) 20%, var(--p-background))",
    "punct" => "color-mix(in oklab, var(--p-foreground) 50%, var(--p-background))",
    "inactive-border" => "rgba(89, 89, 89, 0.67)"
  }.freeze

  def palette_style(theme)
    colors = theme.colors
    hex = ->(key) { colors[key] if HEX.match?(colors[key].to_s) }
    vars = REQUIRED.filter_map { |k| hex.(k) && "--p-#{k}: #{hex.(k)}" }
    DERIVED.each { |k, fallback| vars << "--p-#{k.tr('_', '-')}: #{hex.(k) || fallback}" }
    EXTRA.each { |k, value| vars << "--p-#{k}: #{value}" }
    vars.join("; ")
  end

  # The site's neutral backgrounds (neutral-50 / neutral-950) as sRGB, for contrast checks.
  LIGHT_BG = [ 250, 250, 250 ].freeze
  DARK_BG = [ 10, 10, 10 ].freeze
  MIN_CONTRAST = 3.0

  # Overrides the site's green accent with the theme's own on its page. Each colour mode gets
  # the accent pushed towards black/white until it clears 3:1 against that mode's background,
  # so a dark theme's accent stays readable in light mode and vice versa.
  def theme_primary_style(theme)
    accent = theme.colors["accent"].to_s
    return nil unless HEX.match?(accent)

    rgb = rgb_from_hex(accent)
    light = ensure_contrast(rgb, LIGHT_BG, [ 0, 0, 0 ])
    dark = ensure_contrast(rgb, DARK_BG, [ 255, 255, 255 ])
    [
      "--primary: light-dark(#{hex_from_rgb(light)}, #{hex_from_rgb(dark)})",
      "--primary-foreground: light-dark(#{on_color(light)}, #{on_color(dark)})",
      "--ring: light-dark(#{hex_from_rgb(light)}, #{hex_from_rgb(dark)})"
    ].join("; ")
  end

  private

  def rgb_from_hex(hex)
    digits = hex.delete("#")
    digits = digits.chars.map { |c| c * 2 }.join if digits.size <= 4
    digits[0, 6].scan(/../).map(&:hex)
  end

  def hex_from_rgb(rgb) = "#" + rgb.map { |c| c.round.clamp(0, 255).to_s(16).rjust(2, "0") }.join

  def luminance(rgb)
    r, g, b = rgb.map { |c|
      c /= 255.0
      c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    }
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def contrast(a, b)
    la, lb = luminance(a), luminance(b)
    la, lb = lb, la if lb > la
    (la + 0.05) / (lb + 0.05)
  end

  def ensure_contrast(rgb, background, towards)
    (0..20).each do |i|
      mixed = rgb.zip(towards).map { |c, t| c + (t - c) * i / 20.0 }
      return mixed if contrast(mixed, background) >= MIN_CONTRAST
    end
    towards
  end

  def on_color(rgb) = contrast(rgb, [ 255, 255, 255 ]) >= contrast(rgb, [ 10, 10, 10 ]) ? "#fafafa" : "#0a0a0a"
end
