---
name: propshaft
description: Expert guidance for the Propshaft asset pipeline in Rails 8+. Use when working with assets, stylesheets, CSS organization, JavaScript assets, import maps, asset precompilation, fingerprinting, images, fonts, CDN setup, or migrating from Sprockets. Covers file structure, stylesheet_link_tag, image_tag, @layer ordering, @import, CSS custom properties, asset helpers, deployment, and common Propshaft pitfalls. Trigger on "propshaft", "asset pipeline", "assets", "stylesheet", "javascript assets", "import maps", "asset precompile", "CSS organization", "sprockets migration", "fingerprinting", "stylesheet_link_tag", "image_tag", "asset_path".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails assets:*), Bash(bin/rails server*), Bash(bundle exec rails assets:*)
---

# Rails Propshaft Asset Pipeline Expert

Manage assets in Rails 8+ applications using Propshaft — the modern, minimal asset pipeline that serves files directly without compilation or bundling.

## When To Use This Skill

- Setting up or organizing assets in a Rails 8+ app
- Migrating from Sprockets to Propshaft
- Fixing broken asset paths, missing stylesheets, or fingerprinting issues
- Configuring CDN, import maps, or asset precompilation
- Organizing CSS/JS file structure with Propshaft conventions

## Critical Mental Model

**Propshaft is NOT Sprockets.** Stop thinking in Sprockets patterns immediately:

| Sprockets (OLD — never use) | Propshaft (Rails 8 default) |
|---|---|
| `//= require` directives | Not needed — all files auto-served |
| `//= require_tree .` | Not needed — directory auto-included |
| `asset_path("image.png")` in CSS | `url("/image.png")` in CSS |
| `image-url("bg.png")` Sass helper | `url("/bg.png")` plain CSS |
| `manifest.js` file | Not needed — no manifests |
| Sass/SCSS compilation | Plain CSS (or use cssbundling-rails) |
| Asset compilation step | No compilation — files served as-is |
| `config.assets.compile = true` | Not applicable |

**The #1 agent mistake:** Using `//= require` or Sprockets-era helpers. Propshaft ignores these completely and they'll appear as literal text in your CSS/JS.

## Philosophy

1. **Files are served directly** — No compilation, no bundling, no transformation
2. **Fingerprinting is the core job** — Propshaft digests files for cache busting
3. **CSS `@layer` controls cascade** — Not file load order or manifest declarations
4. **Browser-ready assets only** — Propshaft expects CSS/JS the browser can consume
5. **Simplicity over power** — Need bundling/transpilation? Add jsbundling-rails or cssbundling-rails

## File Organization

### Standard Directory Structure

```
app/assets/
├── stylesheets/
│   ├── application.css        # Main entry — may just declare @layer order
│   ├── _global.css            # Design tokens (CSS custom properties)
│   ├── reset.css              # CSS reset
│   ├── base.css               # Base element styles
│   ├── utilities.css          # Utility classes
│   └── components/
│       ├── buttons.css
│       ├── cards.css
│       ├── forms.css
│       ├── alerts.css
│       └── navigation.css
├── images/
│   ├── logo.svg
│   └── icons/
│       ├── arrow.svg
│       └── check.svg
└── fonts/
    ├── inter-regular.woff2
    └── inter-bold.woff2
```

### Key Rules

- **Every `.css` file in `app/assets/stylesheets/`** is available to serve
- **Underscore prefix** (`_global.css`) is convention only — Propshaft doesn't treat it specially
- **No manifest file** — Unlike Sprockets, no `manifest.js` or `application.css` with `//= require`
- **Subdirectories work** — `components/cards.css` is served as `components/cards.css`

## CSS Organization with @layer

### Declare Layer Order (Critical)

In `application.css` or `_global.css`, declare the cascade order:

```css
/* app/assets/stylesheets/application.css */
@layer reset, base, components, utilities;
```

This single line controls ALL cascade priority. Layers listed later win over earlier ones.

### Wrap Each File in Its Layer

```css
/* app/assets/stylesheets/reset.css */
@layer reset {
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; }
}
```

```css
/* app/assets/stylesheets/components/cards.css */
@layer components {
  .card {
    padding: var(--space-4);
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-md);
  }
}
```

```css
/* app/assets/stylesheets/utilities.css */
@layer utilities {
  .hidden { display: none !important; }
  .text-center { text-align: center; }
}
```

### Why @layer Matters

Without `@layer`, CSS specificity depends on file load order, which Propshaft doesn't guarantee. With `@layer`, the declared order always wins regardless of which file loads first:

1. `reset` — lowest priority (CSS reset, box-sizing)
2. `base` — element defaults (body, headings, links)
3. `components` — UI components (cards, buttons, forms)
4. `utilities` — highest priority (override anything)

**Styles NOT in any @layer have the highest specificity** — they beat all layers. Use this intentionally.

## Design Tokens with CSS Custom Properties

```css
/* app/assets/stylesheets/_global.css */
:root {
  /* Colors */
  --color-primary: #2563eb;
  --color-surface: #ffffff;
  --color-border: #e5e7eb;
  --color-text: #111827;
  --color-text-muted: #6b7280;

  /* Spacing */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
  --space-8: 2rem;

  /* Typography */
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --font-medium: 500;
  --font-bold: 700;

  /* Borders */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
}
```

**Dark mode with `light-dark()`:**

```css
:root {
  color-scheme: light dark;
  --color-surface: light-dark(#ffffff, #1f2937);
  --color-text: light-dark(#111827, #f9fafb);
}
```

## Loading Stylesheets in Layouts

### The :app Symbol (Recommended)

```erb
<%# Loads ALL stylesheets from app/assets/stylesheets/ %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

### Loading Specific Files

```erb
<%# Load third-party CSS first, then app CSS %>
<%= stylesheet_link_tag "actiontext", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

### NEVER Use :all

```erb
<%# BAD — loads engine CSS too (e.g., Bulma from mission_control-jobs) %>
<%= stylesheet_link_tag :all %>

<%# GOOD — only your app's stylesheets %>
<%= stylesheet_link_tag :app %>
```

### Explicit File Order (When Needed)

```erb
<%= stylesheet_link_tag "reset", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "base", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "main", "data-turbo-track": "reload" %>
```

## Asset References

### In Views (ERB)

```erb
<%# Images %>
<%= image_tag "logo.svg", alt: "Company Logo" %>
<%= image_tag "icons/arrow.svg", alt: "Arrow", class: "icon" %>

<%# Stylesheets %>
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>

<%# Favicon %>
<%= favicon_link_tag "favicon.ico" %>

<%# Generic asset path %>
<%= asset_path("document.pdf") %>
```

### In CSS

```css
/* Use root-relative paths — Propshaft rewrites these to digested URLs */
.hero {
  background-image: url("/bg/pattern.svg");
}

.icon-check {
  background-image: url("/icons/check.svg");
}

@font-face {
  font-family: "Inter";
  src: url("/fonts/inter-regular.woff2") format("woff2");
  font-weight: 400;
}
```

Propshaft automatically rewrites `url("/bg/pattern.svg")` → `url("/assets/bg/pattern-abc123.svg")` during precompilation.

### In JavaScript

Use the `RAILS_ASSET_URL` macro:

```javascript
// Propshaft transforms this during precompilation
const trashIcon = RAILS_ASSET_URL("/icons/trash.svg");
// Becomes: "/assets/icons/trash-54g9cbef.svg"
```

## JavaScript with Import Maps

Propshaft handles CSS/images/fonts. JavaScript is managed by **importmap-rails** (Rails 8 default):

```
app/javascript/
├── application.js           # Entry point
└── controllers/             # Stimulus controllers
    ├── hello_controller.js
    └── modal_controller.js
```

```erb
<%# In layout — this is importmap-rails, not Propshaft %>
<%= javascript_importmap_tags %>
```

```ruby
# config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

**Key distinction:** Propshaft fingerprints JS files. Import maps resolve module names to URLs. They complement each other — Propshaft doesn't bundle or transform JS.

## Images and Fonts

### Images

Place in `app/assets/images/`. Reference with helpers:

```erb
<%= image_tag "logo.svg", alt: "Logo", width: 200 %>
<%= image_tag "icons/edit.svg", class: "icon", alt: "" %>
```

In CSS:
```css
.logo { background-image: url("/logo.svg"); }
```

### Fonts

Place in `app/assets/fonts/`. Declare with `@font-face`:

```css
@font-face {
  font-family: "Inter";
  font-weight: 400;
  font-style: normal;
  font-display: swap;
  src: url("/fonts/inter-regular.woff2") format("woff2");
}

@font-face {
  font-family: "Inter";
  font-weight: 700;
  font-style: normal;
  font-display: swap;
  src: url("/fonts/inter-bold.woff2") format("woff2");
}

body {
  font-family: "Inter", system-ui, sans-serif;
}
```

## Deployment and Precompilation

### Precompile Command

```bash
RAILS_ENV=production rails assets:precompile
```

Or without real secrets:
```bash
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 rails assets:precompile
```

This:
1. Copies all assets from load paths to `public/assets/`
2. Fingerprints filenames (e.g., `application-a1b2c3.css`)
3. Rewrites `url()` references in CSS to digested paths
4. Generates `.manifest.json` mapping original → digested filenames

### CDN Configuration

```ruby
# config/environments/production.rb
config.asset_host = ENV.fetch("CDN_HOST", nil)
# e.g., CDN_HOST=https://cdn.example.com
```

### Cache Headers (Web Server)

**Nginx:**
```nginx
location ~ ^/assets/ {
  expires 1y;
  add_header Cache-Control public;
  add_header ETag "";
}
```

**Apache:**
```apache
<Location /assets/>
  Header unset ETag
  FileETag None
  ExpiresActive On
  ExpiresDefault "access plus 1 year"
</Location>
```

### Production Cache-Control

```ruby
# config/environments/production.rb
config.public_file_server.headers = {
  "Cache-Control" => "public, max-age=31536000"
}
```

## Adding New Stylesheets

1. Create the file:
   ```
   app/assets/stylesheets/components/modal.css
   ```

2. Wrap in appropriate `@layer`:
   ```css
   @layer components {
     .modal { /* ... */ }
     .modal-overlay { /* ... */ }
   }
   ```

3. **Done.** Propshaft auto-includes it. No manifest to update, no require directive needed.

## Third-Party / Engine CSS

For gems providing CSS (e.g., Action Text, Trix):

```erb
<%# Load third-party BEFORE :app so your styles can override %>
<%= stylesheet_link_tag "actiontext", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

## Additional Asset Paths

```ruby
# config/initializers/assets.rb
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/stylesheets")
Rails.application.config.assets.paths << Emoji.images_path
```

## Excluding Paths from Digestion

```ruby
# config/initializers/assets.rb
# Useful when using cssbundling-rails with Sass source files
config.assets.excluded_paths = [Rails.root.join("app/assets/stylesheets")]
```

## Debugging

```bash
# List all available assets
bin/rails assets:reveal

# In Rails console
Rails.application.assets.resolver.logical_paths.to_a

# Clear precompiled assets (fix stale development assets)
bin/rails assets:clobber
```

**Common dev issue:** If assets stop updating, you probably ran `assets:precompile` in development. The `.manifest.json` in `public/assets/` tells Rails to use precompiled files. Fix with `rails assets:clobber`.

## Common Mistakes

1. **Using `//= require`** — Propshaft ignores Sprockets directives entirely
2. **Using `image-url()` or `asset-url()`** — These are Sass/Sprockets helpers. Use plain `url("/path")`
3. **Using `:all` instead of `:app`** — `:all` loads engine CSS you don't want
4. **Missing `@layer` declarations** — Without layers, cascade depends on unpredictable file load order
5. **Expecting Sass compilation** — Propshaft serves plain CSS. Use cssbundling-rails or dartsass-rails for Sass
6. **Precompiling in development** — Creates `.manifest.json` that freezes assets. Run `assets:clobber`
7. **Wrong URL format in CSS** — Use `url("/icons/check.svg")` not `url("icons/check.svg")` (root-relative)
8. **Confusing Propshaft and importmap-rails** — Propshaft = CSS/images/fonts. Import maps = JavaScript modules

## Migration from Sprockets

See `reference.md` in this skill directory for the complete migration checklist.

Quick summary:
1. `bundle remove sprockets sprockets-rails sass-rails`
2. Delete `config/assets.rb` and `assets/config/manifest.js`
3. `bundle add propshaft` (or upgrade to Rails 8 which includes it)
4. Replace `//= require` with nothing — files auto-load
5. Replace `image-url()` / `asset-url()` with `url("/path")`
6. Replace `asset_path()` in CSS with `url("/path")`
7. Add `@layer` declarations for cascade control
8. Convert Sass to plain CSS (or add dartsass-rails/cssbundling-rails)
