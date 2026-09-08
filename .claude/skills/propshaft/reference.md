# Propshaft Reference

Detailed patterns, examples, edge cases, and migration guide for the Propshaft asset pipeline.

## Table of Contents
- [How Propshaft Works Internally](#how-propshaft-works-internally)
- [Detailed @layer Patterns](#detailed-layer-patterns)
- [Complete Design Tokens Example](#complete-design-tokens-example)
- [Complete Layout Example](#complete-layout-example)
- [Configuration Reference](#configuration-reference)
- [Asset Helper Reference](#asset-helper-reference)
- [Integrating with Bundlers](#integrating-with-bundlers)
- [Action Text Integration](#action-text-integration)
- [Edge Cases and Gotchas](#edge-cases-and-gotchas)
- [Migration from Sprockets — Complete Checklist](#migration-from-sprockets--complete-checklist)
- [Rails Commands Reference](#rails-commands-reference)

## How Propshaft Works Internally

### Asset Resolution Chain

1. **Development:** Propshaft serves assets directly from configured paths (`app/assets/*`), checking for file changes on each request
2. **Production:** Assets are precompiled to `public/assets/` with fingerprinted filenames. A `.manifest.json` maps logical paths to digested paths

### The Manifest File

Generated during `rails assets:precompile`:

```json
{
  "application.css": "application-6d58c9e6e3b5d4.css",
  "components/cards.css": "components/cards-a8f3b2c1.css",
  "logo.svg": "logo-f3e8c9b2a6e5.svg",
  "fonts/inter-regular.woff2": "fonts/inter-regular-c7d2e1f0.woff2"
}
```

Asset helpers (`stylesheet_link_tag`, `image_tag`, `asset_path`) use this mapping in production. In development, they resolve to the raw file paths.

### CSS URL Rewriting

Propshaft's only "compilation" step: rewriting `url()` references in CSS to their digested paths.

```css
/* Source */
.icon { background: url("/icons/check.svg"); }

/* After precompilation */
.icon { background: url("/assets/icons/check-a1b2c3.svg"); }
```

This also rewrites source map comments:
```css
/* Source */
/*# sourceMappingURL=app.css.map */

/* After precompilation */
/*# sourceMappingURL=app-d4e5f6.css.map */
```

### JavaScript RAILS_ASSET_URL Macro

Propshaft rewrites `RAILS_ASSET_URL()` calls in `.js` files:

```javascript
// Source
const icon = RAILS_ASSET_URL("/icons/trash.svg");

// After precompilation
const icon = "/assets/icons/trash-54g9cbef.svg";
```

**Important:** This only works in files served by Propshaft (in `app/assets/`). It does NOT work in `app/javascript/` files managed by importmap-rails or bundlers. For those, use ERB templates or data attributes.

### Pre-Digested Files

Files matching `-[digest].digested.{ext}` are treated as already fingerprinted:

```
vendor/assets/javascripts/library-abc123.digested.js
```

Propshaft preserves the filename without adding another digest. Useful for vendored files that include source maps.

## Detailed @layer Patterns

### Full Layer Stack

```css
/* app/assets/stylesheets/application.css */
@layer reset, base, layout, components, utilities;
```

### Reset Layer

```css
/* app/assets/stylesheets/reset.css */
@layer reset {
  *, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  html {
    -moz-text-size-adjust: none;
    -webkit-text-size-adjust: none;
    text-size-adjust: none;
  }

  body {
    min-height: 100dvh;
    line-height: 1.5;
  }

  img, picture, video, canvas, svg {
    display: block;
    max-width: 100%;
  }

  input, button, textarea, select {
    font: inherit;
  }
}
```

### Base Layer

```css
/* app/assets/stylesheets/base.css */
@layer base {
  body {
    font-family: var(--font-family);
    font-size: var(--text-base);
    color: var(--color-text);
    background-color: var(--color-surface);
  }

  a {
    color: var(--color-primary);
    text-decoration: underline;
    text-underline-offset: 0.15em;
  }

  a:hover {
    text-decoration: none;
  }

  h1, h2, h3, h4 {
    line-height: 1.2;
    font-weight: var(--font-bold);
  }

  h1 { font-size: var(--text-3xl); }
  h2 { font-size: var(--text-2xl); }
  h3 { font-size: var(--text-xl); }
}
```

### Layout Layer

```css
/* app/assets/stylesheets/layout.css */
@layer layout {
  .app-layout {
    display: grid;
    grid-template-rows: auto 1fr auto;
    min-height: 100dvh;
  }

  .container {
    width: 100%;
    max-width: var(--container-max);
    margin-inline: auto;
    padding-inline: var(--space-4);
  }

  .sidebar-layout {
    display: grid;
    grid-template-columns: 16rem 1fr;
    gap: var(--space-6);
  }
}
```

### Component Layer

```css
/* app/assets/stylesheets/components/buttons.css */
@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    font-weight: var(--font-medium);
    border-radius: var(--radius-md);
    border: 1px solid transparent;
    cursor: pointer;
    text-decoration: none;
    transition: background-color 0.15s, border-color 0.15s;
  }

  .btn-primary {
    background-color: var(--color-primary);
    color: white;
  }

  .btn-primary:hover {
    background-color: var(--color-primary-dark);
  }

  .btn-outline {
    border-color: var(--color-border);
    background: transparent;
    color: var(--color-text);
  }

  .btn-outline:hover {
    background-color: var(--color-surface-hover);
  }
}
```

### Utility Layer

```css
/* app/assets/stylesheets/utilities.css */
@layer utilities {
  .hidden { display: none !important; }
  .sr-only {
    position: absolute;
    width: 1px; height: 1px;
    padding: 0; margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }
  .text-center { text-align: center; }
  .text-right { text-align: right; }
  .font-bold { font-weight: var(--font-bold); }
  .mt-4 { margin-top: var(--space-4); }
  .mb-4 { margin-bottom: var(--space-4); }
  .flex { display: flex; }
  .flex-col { flex-direction: column; }
  .items-center { align-items: center; }
  .justify-between { justify-content: space-between; }
  .gap-2 { gap: var(--space-2); }
  .gap-4 { gap: var(--space-4); }
}
```

### Styles Outside @layer

**Styles NOT wrapped in any `@layer` have the highest specificity** — they beat all layered styles:

```css
/* This beats ANYTHING in @layer components or @layer utilities */
.critical-override {
  color: red;
}
```

Use this intentionally for third-party overrides or truly global overrides. Don't leave styles un-layered by accident.

## Complete Design Tokens Example

```css
/* app/assets/stylesheets/_global.css */
:root {
  /* === Color System === */
  color-scheme: light dark;

  /* Primitives */
  --color-blue-500: #3b82f6;
  --color-blue-600: #2563eb;
  --color-blue-700: #1d4ed8;
  --color-red-500: #ef4444;
  --color-red-600: #dc2626;
  --color-green-500: #22c55e;
  --color-green-600: #16a34a;
  --color-zinc-50: #fafafa;
  --color-zinc-100: #f4f4f5;
  --color-zinc-200: #e4e4e7;
  --color-zinc-700: #3f3f46;
  --color-zinc-800: #27272a;
  --color-zinc-900: #18181b;

  /* Semantic tokens (light/dark aware) */
  --color-primary: light-dark(var(--color-blue-600), var(--color-blue-500));
  --color-primary-dark: light-dark(var(--color-blue-700), var(--color-blue-600));
  --color-danger: light-dark(var(--color-red-600), var(--color-red-500));
  --color-success: light-dark(var(--color-green-600), var(--color-green-500));
  --color-surface: light-dark(white, var(--color-zinc-900));
  --color-surface-raised: light-dark(var(--color-zinc-50), var(--color-zinc-800));
  --color-surface-hover: light-dark(var(--color-zinc-100), var(--color-zinc-700));
  --color-border: light-dark(var(--color-zinc-200), var(--color-zinc-700));
  --color-text: light-dark(var(--color-zinc-900), var(--color-zinc-50));
  --color-text-muted: light-dark(#6b7280, #9ca3af);

  /* === Spacing Scale === */
  --space-0: 0;
  --space-1: 0.25rem;   /* 4px */
  --space-2: 0.5rem;    /* 8px */
  --space-3: 0.75rem;   /* 12px */
  --space-4: 1rem;      /* 16px */
  --space-5: 1.25rem;   /* 20px */
  --space-6: 1.5rem;    /* 24px */
  --space-8: 2rem;      /* 32px */
  --space-10: 2.5rem;   /* 40px */
  --space-12: 3rem;     /* 48px */
  --space-16: 4rem;     /* 64px */

  /* === Typography === */
  --font-family: "Inter", system-ui, -apple-system, sans-serif;
  --font-mono: ui-monospace, "Cascadia Code", "Source Code Pro", monospace;

  --text-xs: 0.75rem;    /* 12px */
  --text-sm: 0.875rem;   /* 14px */
  --text-base: 1rem;     /* 16px */
  --text-lg: 1.125rem;   /* 18px */
  --text-xl: 1.25rem;    /* 20px */
  --text-2xl: 1.5rem;    /* 24px */
  --text-3xl: 1.875rem;  /* 30px */
  --text-4xl: 2.25rem;   /* 36px */

  --font-normal: 400;
  --font-medium: 500;
  --font-semibold: 600;
  --font-bold: 700;

  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;

  /* === Borders & Radius === */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-xl: 0.75rem;
  --radius-full: 9999px;

  /* === Shadows === */
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);

  /* === Layout === */
  --container-max: 72rem;  /* 1152px */

  /* === Transitions === */
  --transition-fast: 0.15s ease;
  --transition-normal: 0.2s ease;
}
```

## Complete Layout Example

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= content_for(:title) || "My App" %></title>

  <%# Third-party CSS first (so app styles can override) %>
  <%= stylesheet_link_tag "actiontext", "data-turbo-track": "reload" %>

  <%# App CSS — :app loads everything from app/assets/stylesheets/ %>
  <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>

  <%# JavaScript via importmap-rails %>
  <%= javascript_importmap_tags %>

  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
</head>
<body>
  <%= yield %>
</body>
</html>
```

## Configuration Reference

### config/environments/development.rb

```ruby
# Propshaft defaults for development:
# - No fingerprinting
# - No caching
# - File watcher checks for changes on each request

# Optional: Use evented file watcher for better performance
config.file_watcher = ActiveSupport::EventedFileUpdateChecker
```

### config/environments/production.rb

```ruby
# CDN host
config.asset_host = ENV.fetch("CDN_HOST", nil)

# Cache headers for static files
config.public_file_server.headers = {
  "Cache-Control" => "public, max-age=31536000"
}
```

### config/initializers/assets.rb

```ruby
# Add extra asset paths
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/stylesheets")
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/images")

# Exclude directories from digestion (e.g., Sass source files)
# Rails.application.config.assets.excluded_paths = [
#   Rails.root.join("app/assets/stylesheets/sass")
# ]
```

## Asset Helper Reference

### View Helpers

| Helper | Example | Output |
|--------|---------|--------|
| `stylesheet_link_tag` | `stylesheet_link_tag :app` | `<link rel="stylesheet" href="/assets/application-abc123.css">` |
| `javascript_include_tag` | `javascript_include_tag "main"` | `<script src="/assets/main-def456.js">` |
| `image_tag` | `image_tag "logo.svg"` | `<img src="/assets/logo-789abc.svg">` |
| `favicon_link_tag` | `favicon_link_tag "favicon.ico"` | `<link rel="icon" href="/assets/favicon-abc123.ico">` |
| `asset_path` | `asset_path "doc.pdf"` | `/assets/doc-def456.pdf` |
| `asset_url` | `asset_url "doc.pdf"` | `https://cdn.example.com/assets/doc-def456.pdf` |

### stylesheet_link_tag Symbols

| Symbol | Loads |
|--------|-------|
| `:app` | All stylesheets from `app/assets/stylesheets/` |
| `:all` | **Avoid** — loads ALL stylesheets including engine CSS |
| `"name"` | Single file `app/assets/stylesheets/name.css` |

### CSS url() Paths

| Pattern | Works? | Notes |
|---------|--------|-------|
| `url("/icons/check.svg")` | ✅ | Root-relative — Propshaft rewrites to digested path |
| `url("/fonts/inter.woff2")` | ✅ | Root-relative for fonts |
| `url("icons/check.svg")` | ⚠️ | Relative — resolves from CSS file location, fragile |
| `url("data:image/svg+xml,...")` | ✅ | Inline data URIs work fine |
| `image-url("check.svg")` | ❌ | Sprockets/Sass helper — not recognized |
| `asset-url("check.svg")` | ❌ | Sprockets/Sass helper — not recognized |

## Integrating with Bundlers

### With jsbundling-rails (esbuild/rollup/webpack)

Propshaft serves the bundled output. The bundler writes to `app/assets/builds/`:

```
app/assets/builds/
  application.js     # Bundled by esbuild
```

Propshaft fingerprints and serves this file. The bundler handles the transform; Propshaft handles delivery.

### With cssbundling-rails (Tailwind/Bootstrap/Sass)

Same pattern — CSS tool writes compiled output to `app/assets/builds/`:

```
app/assets/builds/
  application.css    # Compiled by Tailwind/Sass/PostCSS
```

**Important:** When using cssbundling-rails, exclude the source files from Propshaft:

```ruby
# config/initializers/assets.rb
config.assets.excluded_paths = [Rails.root.join("app/assets/stylesheets")]
```

This prevents Propshaft from serving both source Sass AND compiled CSS.

### With tailwindcss-rails (Standalone)

Tailwind CSS processes `app/assets/stylesheets/application.tailwind.css` and writes output to `app/assets/builds/application.css`. No Node.js required.

## Action Text Integration

Action Text ships its own CSS. Load it before your app styles:

```erb
<%= stylesheet_link_tag "actiontext", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

To customize Action Text styles, add overrides in your own CSS wrapped in the appropriate `@layer`:

```css
@layer components {
  .trix-content h1 { font-size: var(--text-2xl); }
  .trix-content a { color: var(--color-primary); }
}
```

## Edge Cases and Gotchas

### 1. Precompiled Assets in Development

**Symptom:** CSS/JS changes don't appear in browser.

**Cause:** You ran `rails assets:precompile` in development, creating `public/assets/.manifest.json`.

**Fix:**
```bash
bin/rails assets:clobber
```

### 2. Missing Assets in Production

**Symptom:** `ActionView::Template::Error: The asset "whatever.css" is not present in the asset pipeline`

**Causes:**
- File doesn't exist in any path registered in `config.assets.paths`
- File is in an excluded path
- Precompilation didn't run or failed silently

**Debug:**
```ruby
# Rails console
Rails.application.assets.resolver.logical_paths.to_a
# => ["application.css", "components/cards.css", ...]
```

### 3. Engine CSS Leaking Into Your App

**Symptom:** Unexpected styles (e.g., Bulma CSS from mission_control-jobs).

**Cause:** Using `stylesheet_link_tag :all` which loads engine stylesheets.

**Fix:** Use `stylesheet_link_tag :app` instead.

### 4. CSS url() Not Resolving

**Symptom:** Background images or fonts 404 in production.

**Cause:** Using relative paths instead of root-relative:

```css
/* WRONG — relative, fragile */
background: url("../images/bg.png");

/* RIGHT — root-relative, Propshaft rewrites correctly */
background: url("/images/bg.png");
```

### 5. Fonts Not Loading

**Checklist:**
1. Font files in `app/assets/fonts/` ✓
2. `@font-face` uses root-relative paths: `url("/fonts/inter.woff2")` ✓
3. CORS headers set if using CDN ✓
4. `font-display: swap` set for performance ✓

### 6. @layer Order Not Working

**Symptom:** Component styles override utility styles unexpectedly.

**Cause:** `@layer` declaration missing or declared in wrong file.

**Fix:** Ensure a single `@layer` order declaration exists, loaded before any layered styles:

```css
/* Must appear ONCE, early in cascade */
@layer reset, base, layout, components, utilities;
```

### 7. Third-Party CSS Overriding Your Styles

**Strategy:** Load third-party CSS before `:app`:

```erb
<%= stylesheet_link_tag "trix", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

Your `@layer components` and `@layer utilities` styles will override third-party styles because layered CSS from `:app` loads after.

If the third-party CSS doesn't use `@layer`, it sits at the unlayered level (highest priority). Override with unlayered CSS or higher-specificity selectors.

### 8. Source Maps

Propshaft rewrites source map comments to point to digested filenames. For vendored files with embedded source maps, use the pre-digested naming convention:

```
vendor/assets/javascripts/library-abc123.digested.js
vendor/assets/javascripts/library-abc123.digested.js.map
```

## Migration from Sprockets — Complete Checklist

### Phase 1: Remove Sprockets

```bash
bundle remove sprockets sprockets-rails sass-rails
```

Delete these files:
- `config/assets.rb`
- `assets/config/manifest.js`
- `app/assets/config/manifest.js`

### Phase 2: Install Propshaft

```bash
bundle add propshaft
```

Or upgrade to Rails 8+ where it's the default.

### Phase 3: Clean Up Directives

Remove ALL Sprockets directives from CSS and JS files:

```css
/* REMOVE these lines: */
/*
 *= require_tree .
 *= require_self
 *= require reset
 */
```

```javascript
// REMOVE these lines:
//= require jquery
//= require_tree .
```

With Propshaft, all files are auto-served. No directives needed.

### Phase 4: Fix Asset References in CSS

| Sprockets | Propshaft |
|-----------|-----------|
| `image-url("bg.png")` | `url("/bg.png")` |
| `asset-url("font.woff2")` | `url("/fonts/font.woff2")` |
| `asset-path("doc.pdf")` | `url("/doc.pdf")` |
| `font-url("inter.woff2")` | `url("/fonts/inter.woff2")` |

### Phase 5: Convert Sass to CSS (if not using cssbundling-rails)

If you were using Sass via Sprockets:

**Option A:** Convert to plain CSS (recommended for simple apps)
- Replace variables with CSS custom properties
- Replace nesting with flat selectors (or use native CSS nesting)
- Replace mixins with CSS classes or custom properties
- Remove `@import` of partials (Propshaft auto-includes all files)

**Option B:** Keep Sass via dartsass-rails or cssbundling-rails
```bash
bundle add dartsass-rails
# OR
bundle add cssbundling-rails
```

### Phase 6: Add @layer Declarations

Add cascade control that Sprockets' load order previously provided:

```css
/* app/assets/stylesheets/application.css */
@layer reset, base, layout, components, utilities;
```

Wrap existing CSS files in appropriate layers.

### Phase 7: Fix Layout References

```erb
<%# Sprockets style — REMOVE %>
<%= stylesheet_link_tag "application", media: "all" %>

<%# Propshaft style — USE %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

### Phase 8: Remove Sprockets Config

Remove from `config/application.rb`:
```ruby
# REMOVE
config.assets.paths << Rails.root.join('app', 'assets')
config.assets.compile = true
config.assets.css_compressor = :yui
```

### Phase 9: Verify

```bash
# Development
bin/rails server
# Check browser — all styles/images/fonts load correctly

# Production simulation
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
ls public/assets/  # Verify fingerprinted files exist
bin/rails assets:clobber  # Clean up
```

## Rails Commands Reference

```bash
# Precompile assets for production
RAILS_ENV=production rails assets:precompile

# Precompile without real secrets
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 rails assets:precompile

# Remove all precompiled assets
bin/rails assets:clobber

# Show all available asset paths
bin/rails assets:reveal

# List logical asset paths (console)
Rails.application.assets.resolver.logical_paths.to_a
```
