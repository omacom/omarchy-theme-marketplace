# Dark Mode Deep Dive

Patterns for implementing dark mode using `light-dark()`, `color-scheme`, and manual toggles.

---

## How light-dark() Works

`light-dark()` is a CSS function that returns its first argument in light mode and its second in dark mode. It requires `color-scheme` to be set on an ancestor.

```css
:root {
  color-scheme: light dark;  /* Required — enables light-dark() */
}

/* light-dark(light-value, dark-value) */
--color-surface: light-dark(white, var(--color-zinc-800));
```

The browser determines "light" or "dark" based on:
1. The `color-scheme` property on the element or ancestor
2. The user's OS preference (`prefers-color-scheme`)
3. Manual override via `data-theme` attribute

## Manual Theme Toggle Pattern

```html
<!-- In <head>, before any CSS loads -->
<script>
  // Apply saved theme before first paint to prevent flash
  const theme = localStorage.getItem('theme');
  if (theme) document.documentElement.dataset.theme = theme;
</script>
```

```css
/* Override color-scheme with data attribute */
html[data-theme="light"] { color-scheme: light; }
html[data-theme="dark"]  { color-scheme: dark; }
```

```javascript
// Toggle function
function toggleTheme() {
  const html = document.documentElement;
  const current = html.dataset.theme;
  const next = current === 'dark' ? 'light' : 'dark';
  html.dataset.theme = next;
  localStorage.setItem('theme', next);
}

// Reset to system preference
function resetTheme() {
  delete document.documentElement.dataset.theme;
  localStorage.removeItem('theme');
}
```

**Stimulus controller version:**

```javascript
// app/javascript/controllers/theme_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle() {
    const html = document.documentElement
    const current = html.dataset.theme
    const next = current === "dark" ? "light" : "dark"
    html.dataset.theme = next
    localStorage.setItem("theme", next)
  }

  reset() {
    delete document.documentElement.dataset.theme
    localStorage.removeItem("theme")
  }
}
```

## Shadows in Dark Mode

Shadows are nearly invisible against dark backgrounds. Use elevation through borders and surface tones instead.

```css
/* Light mode mental model: elevation = shadows */
/* Dark mode mental model: elevation = lighter surfaces */

.card {
  /* Don't rely on shadows for structure */
  border: 1px solid var(--color-border);
}

/* If you must use shadows, keep them very subtle */
.card-elevated {
  box-shadow: var(--shadow-sm);  /* 0 1px 2px rgb(0 0 0 / 0.04) */
}

/* Elevation via surface color is better */
.surface-base   { background: var(--color-canvas); }      /* Lowest */
.surface-card   { background: var(--color-surface); }      /* Middle */
.surface-raised { background: var(--color-surface-raised); } /* Highest */
```

## color-mix() for Tinted Backgrounds

`color-mix()` creates tinted backgrounds that work in both modes:

```css
.badge-feature {
  color: var(--color-purple-600);
  /* Mix 15% of the accent color with the surface color */
  background: color-mix(in oklch, var(--color-purple-500) 15%, var(--color-surface));
}

/* Hover state — slightly more saturated */
.tag:hover {
  background: color-mix(in oklch, var(--color-primary) 20%, var(--color-surface));
}
```

## State Colors Need Three Tokens

Every state (success, error, warning) needs foreground, background, and border:

```css
:root {
  /* Each state gets a complete set */
  --color-positive:        light-dark(var(--color-green-600), var(--color-green-500));
  --color-positive-canvas: light-dark(var(--color-green-50), var(--color-green-950));
  --color-positive-border: light-dark(var(--color-green-200), var(--color-green-800));
}

.alert-success {
  color: var(--color-positive);
  background: var(--color-positive-canvas);
  border: 1px solid var(--color-positive-border);
}
```

## Browser Fallback

For browsers that don't support `light-dark()` (pre-2024):

```css
/* Fallback: define defaults, then override in media query */
:root {
  --color-surface: white;
  --color-ink: #18181b;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-surface: #27272a;
    --color-ink: #fafafa;
  }
}

/* Modern browsers: use light-dark() — overrides the fallback */
@supports (color: light-dark(red, red)) {
  :root {
    --color-surface: light-dark(white, #27272a);
    --color-ink: light-dark(#18181b, #fafafa);
  }
}
```
