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
end
