---
name: css-architecture
description: Expert guidance for CSS architecture in Rails applications using modern CSS (no Tailwind). Use when writing stylesheets, organizing CSS files, implementing dark mode, defining design tokens, using CSS custom properties, creating component styles, working with CSS layers (@layer), using the light-dark() function, setting up color schemes, or structuring CSS for maintainability. Covers design tokens, semantic color systems, component-scoped styles, utility classes, responsive patterns, and file organization.
allowed-tools: Read, Grep, Glob, Write, Edit
---

# Rails CSS Architecture Expert

Write maintainable, scalable CSS for Rails applications using modern CSS features — custom properties, `@layer`, `light-dark()`, and semantic design tokens. No framework dependency.

## Philosophy

**Core Principles:**
1. **Components own their styles** — One CSS file per component, never style components from page stylesheets
2. **Design tokens over magic numbers** — All values come from `_global.css` custom properties
3. **Layers control the cascade** — Use `@layer` instead of specificity hacks or `!important`
4. **Dark mode is free** — `color-scheme` + `light-dark()` gives you dark mode with zero extra work
5. **Utilities are seasoning, not the meal** — Use sparingly for one-off adjustments, not as primary styling

**Architecture Pyramid:**
```
      /\       Utilities (few — spacing/text tweaks)
     /  \
    /____\     Components (many — reusable UI pieces)
   /      \
  /________\   Base (element defaults, resets)
 /          \
/____________\ Tokens (_global.css — design system foundation)
```

## When To Use This Skill

- Creating or reorganizing CSS file structure in a Rails app
- Writing new component stylesheets
- Implementing dark mode support
- Defining or extending design tokens
- Debugging cascade/specificity issues
- Converting from Tailwind or other frameworks to vanilla CSS
- Setting up CSS layers
- Creating utility classes
- Integrating third-party CSS libraries

## Instructions

### Step 1: Understand the File Structure

Every Rails app using this architecture has this structure:

```
app/assets/stylesheets/
├── _global.css              # Design tokens: colors, spacing, typography, radii
├── application.css          # Entry point — may just import everything
├── reset.css                # CSS reset / normalization
├── base.css                 # Element defaults (no classes)
├── utilities.css            # Single-purpose utility classes
└── components/
    ├── app-layout.css       # Main layout shell
    ├── forms.css            # Form elements + buttons
    ├── cards.css            # Card component
    ├── badges.css           # Badge variants
    ├── alerts.css           # Alerts/flash messages
    ├── tables.css           # Table styles
    └── [feature].css        # Feature-specific components
```

**ALWAYS check the existing structure first:**

```bash
# See what exists
find app/assets/stylesheets -name "*.css" | sort

# Check for existing tokens
cat app/assets/stylesheets/_global.css

# Check layer declarations
rg "@layer" app/assets/stylesheets/

# Check for existing components
ls app/assets/stylesheets/components/
```

**Match existing project conventions** — consistency beats "ideal" patterns.

### Step 2: Set Up CSS Layers

Declare layers once at the top of `_global.css` (or `application.css`):

```css
/* _global.css — FIRST LINE */
@layer reset, base, components, utilities;
```

Layer priority (lowest → highest):
1. **reset** — Browser normalization
2. **base** — Element defaults (`h1`, `a`, `input`)
3. **components** — UI components (`.card`, `.btn`, `.badge`)
4. **utilities** — Override helpers (`.mt-4`, `.hidden`) — always wins

Every CSS rule goes inside its layer:

```css
/* base.css */
@layer base {
  body { font-family: var(--font-sans); color: var(--color-ink); }
  a { color: var(--color-link); }
}

/* components/cards.css */
@layer components {
  .card { background: var(--color-surface); border: 1px solid var(--color-border); }
}

/* utilities.css */
@layer utilities {
  .mt-4 { margin-top: var(--space-4); }
}
```

**Why layers matter:** Without `@layer`, you fight specificity with nesting, `!important`, or load order hacks. Layers eliminate all of that. A utility in the `utilities` layer beats any component rule regardless of specificity.

### Step 3: Define Design Tokens

All design values live in `_global.css` as custom properties on `:root`:

```css
:root {
  /* Enable dark mode detection */
  color-scheme: light dark;

  /* === Raw Palette (OKLCH for perceptual uniformity) === */
  --color-zinc-50:  oklch(0.985 0 0);
  --color-zinc-100: oklch(0.967 0.001 286.375);
  --color-zinc-200: oklch(0.92 0.004 286.32);
  --color-zinc-400: oklch(0.707 0.022 261);
  --color-zinc-500: oklch(0.552 0.016 285.938);
  --color-zinc-700: oklch(0.37 0.013 285.805);
  --color-zinc-800: oklch(0.274 0.006 286.033);
  --color-zinc-900: oklch(0.21 0.006 285.885);
  --color-zinc-950: oklch(0.141 0.005 285.823);

  /* === Semantic Color Tokens === */
  /* Surfaces */
  --color-canvas: light-dark(var(--color-zinc-50), var(--color-zinc-900));
  --color-surface: light-dark(white, var(--color-zinc-800));
  --color-surface-raised: light-dark(white, var(--color-zinc-700));
  --color-surface-muted: light-dark(var(--color-zinc-100), var(--color-zinc-800));

  /* Text */
  --color-ink: light-dark(var(--color-zinc-900), var(--color-zinc-50));
  --color-ink-muted: light-dark(var(--color-zinc-500), var(--color-zinc-400));
  --color-ink-subtle: light-dark(var(--color-zinc-400), var(--color-zinc-500));

  /* Borders */
  --color-border: light-dark(var(--color-zinc-200), var(--color-zinc-700));
  --color-border-muted: light-dark(var(--color-zinc-100), var(--color-zinc-800));
  --color-border-strong: light-dark(var(--color-zinc-400), var(--color-zinc-600));

  /* Interactive */
  --color-primary: light-dark(var(--color-blue-600), var(--color-blue-500));
  --color-primary-hover: light-dark(var(--color-blue-700), var(--color-blue-400));
  --color-link: light-dark(var(--color-blue-600), var(--color-blue-400));

  /* State */
  --color-positive: light-dark(var(--color-green-600), var(--color-green-500));
  --color-positive-canvas: light-dark(var(--color-green-50), var(--color-green-950));
  --color-negative: light-dark(var(--color-red-600), var(--color-red-500));
  --color-negative-canvas: light-dark(var(--color-red-50), var(--color-red-950));

  /* === Spacing Scale === */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 0.75rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
  --space-8: 2rem;
  --space-12: 3rem;

  /* === Typography === */
  --font-sans: system-ui, -apple-system, sans-serif;
  --font-mono: ui-monospace, "SF Mono", monospace;
  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --text-xl: 1.25rem;
  --text-2xl: 1.5rem;
  --font-medium: 500;
  --font-semibold: 600;
  --font-bold: 700;

  /* === Radii === */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-xl: 0.75rem;
  --radius-full: 9999px;

  /* === Transitions === */
  --duration-fast: 150ms;
  --duration-normal: 250ms;
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
}
```

**Rule: Components NEVER use raw values. Always reference tokens.**

```css
/* GOOD */
.card { padding: var(--space-6); background: var(--color-surface); }

/* BAD — hardcoded values */
.card { padding: 1.5rem; background: white; }
```

### Step 4: Write Component Styles

Each component gets its own file in `components/`. Components use tokens only.

**Component structure:**

```css
/* components/cards.css */
@layer components {
  /* Base */
  .card {
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: var(--radius-lg);
    padding: var(--space-6);
  }

  /* Structural subcomponents */
  .card-header { padding-bottom: var(--space-4); border-bottom: 1px solid var(--color-border-muted); }
  .card-body { padding-top: var(--space-4); }
  .card-footer { padding-top: var(--space-4); border-top: 1px solid var(--color-border-muted); }

  /* Variants */
  .card-sm { padding: var(--space-4); }
  .card-lg { padding: var(--space-8); }

  /* States */
  .card-interactive { transition: border-color var(--duration-fast) var(--ease-out); }
  .card-interactive:hover { border-color: var(--color-border-strong); }
}
```

**Naming conventions:**
- Base: `.card`, `.btn`, `.badge`
- Subcomponents: `.card-header`, `.card-body`
- Variants: `.card-sm`, `.btn-primary`
- States: `.is-loading`, `.is-active`

**When to create a new component file:**
- Pattern used 3+ times
- Has related sub-classes (`.foo`, `.foo-header`, `.foo-item`)
- Has variants (`.foo-primary`, `.foo-small`)

**Keep it in a page stylesheet when:**
- Truly page-specific (used once)
- Simple layout (grid, flex container)

### Step 5: Dark Mode with light-dark()

Dark mode is automatic when you follow the token system. Here's how:

1. **Set `color-scheme: light dark` on `:root`** — browsers respect OS preference
2. **Define semantic tokens with `light-dark()`** — first value = light, second = dark
3. **Components reference semantic tokens** — they adapt automatically

```css
:root {
  color-scheme: light dark;
  --color-surface: light-dark(white, var(--color-zinc-800));
  --color-ink: light-dark(var(--color-zinc-900), var(--color-zinc-50));
}

/* This component supports dark mode with ZERO extra work */
.card {
  background: var(--color-surface);
  color: var(--color-ink);
}
```

**Optional manual toggle:**

```css
html[data-theme="light"] { color-scheme: light; }
html[data-theme="dark"]  { color-scheme: dark; }
```

```javascript
function toggleTheme() {
  const current = document.documentElement.dataset.theme;
  const next = current === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('theme', next);
}
```

**Flash prevention — put this in `<head>`:**

```html
<script>
  const theme = localStorage.getItem('theme');
  if (theme) document.documentElement.dataset.theme = theme;
</script>
```

**Dark mode rules:**
- Shadows don't work in dark mode — prefer borders
- Use `color-mix()` for subtle tinted backgrounds
- State colors need both a foreground and canvas variant
- Never use raw white/black — always use semantic tokens

### Step 6: Write Utility Classes

Utilities go in `utilities.css` inside `@layer utilities`. They are single-purpose and immutable:

```css
@layer utilities {
  /* Spacing */
  .mt-2 { margin-top: var(--space-2); }
  .mt-4 { margin-top: var(--space-4); }
  .mt-6 { margin-top: var(--space-6); }
  .mb-4 { margin-bottom: var(--space-4); }
  .p-4 { padding: var(--space-4); }
  .gap-4 { gap: var(--space-4); }

  /* Text */
  .text-sm { font-size: var(--text-sm); }
  .text-muted { color: var(--color-ink-muted); }
  .font-medium { font-weight: var(--font-medium); }

  /* Layout */
  .flex { display: flex; }
  .grid { display: grid; }
  .hidden { display: none; }
  .sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); }
}
```

**Use utilities for one-off adjustments:**

```erb
<%# Good — utility for spacing adjustment %>
<div class="card mt-6">

<%# Bad — utilities replacing component styles %>
<div class="p-6 bg-white border rounded-lg shadow">
```

### Step 7: Page Stylesheets Are Thin

Page-specific styles should be minimal — just layout:

```css
/* pages/dashboard.css */
@layer components {
  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: var(--space-6);
  }
}
```

Pages compose existing pieces:

```erb
<div class="dashboard-grid">
  <div class="card">...</div>
  <div class="card">...</div>
  <div class="card mt-4">...</div>  <%# Component + utility %>
</div>
```

**Never style components from page stylesheets:**

```css
/* BAD — page overriding component */
.dashboard .card { padding: 2rem; }

/* GOOD — create a variant in the component file */
.card-lg { padding: var(--space-8); }
```

### Step 8: Integrate Third-Party CSS

When integrating external libraries, map their variables to your tokens:

```css
:root {
  --lexxy-color-ink: var(--color-ink);
  --lexxy-color-canvas: var(--color-surface);
  --lexxy-color-selected: light-dark(oklch(0.92 0.026 254), oklch(0.3 0.05 254));
}
```

**Load order matters** — library CSS BEFORE your overrides:

```erb
<%= stylesheet_link_tag "lexxy" %>
<%= stylesheet_link_tag :app %>
```

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Hardcode colors (`white`, `#333`) | Use semantic tokens (`var(--color-surface)`) |
| `!important` | Use `@layer` for cascade control |
| Deep nesting (`.page .section .card .title`) | Flat, specific classes (`.card-title`) |
| Generic names (`.container`, `.title`) | Prefixed names (`.page-container`, `.card-title`) |
| Style components from page CSS | Create component variants |
| Inline styles in ERB | Use utility classes or component classes |
| `box-shadow` for dark mode elevation | Use borders |
| Magic numbers (`padding: 23px`) | Use spacing tokens (`var(--space-6)`) |
| Media queries for dark mode | Use `light-dark()` with `color-scheme` |
| Framework-specific classes in views | Use your own semantic classes |

## Quick Reference

### Naming Conventions

```
.component           → .card, .btn, .badge
.component-sub       → .card-header, .card-body
.component-variant   → .card-sm, .btn-primary
.component-state     → .card-interactive (or .is-loading for global states)
.page-element        → .dashboard-grid, .settings-sidebar
```

### Responsive Patterns

```css
/* Mobile-first with container queries where possible */
.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-4);
}

@media (min-width: 768px) {
  .dashboard-grid {
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: var(--space-6);
  }
}
```

### Browser Support

`light-dark()` requires Chrome 123+, Firefox 120+, Safari 17.5+.

Fallback for older browsers:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-surface: var(--color-zinc-800);
    --color-ink: var(--color-zinc-50);
  }
}
```

### New Component Checklist

- [ ] Created `components/[name].css`
- [ ] Wrapped all rules in `@layer components { }`
- [ ] All values reference design tokens (no magic numbers)
- [ ] Uses semantic color tokens (not raw palette)
- [ ] Class names are specific and won't collide
- [ ] Subcomponents follow `.component-sub` naming
- [ ] Dark mode works automatically (verified)
- [ ] Imported in `application.css` if needed

### Design Token Checklist

- [ ] New tokens added to `_global.css` under `:root`
- [ ] Color tokens use `light-dark()` for both modes
- [ ] Raw palette values use OKLCH
- [ ] Spacing follows the existing scale
- [ ] Token names are semantic (`--color-surface`, not `--color-white`)

For detailed patterns and examples, see the `references/` directory:
- `references/design-tokens.md` — Full color palette (OKLCH), spacing, typography, naming conventions
- `references/components.md` — Button, card, badge, alert, form, table patterns + Rails integration
- `references/dark-mode.md` — `light-dark()` deep dive, manual toggle, shadows, `color-mix()`
- `references/responsive.md` — Mobile-first breakpoints, container queries, fluid typography, layout patterns
- `references/layers.md` — `@layer` cascade control, anti-patterns, third-party CSS
- `references/utilities.md` — Complete recommended utility class set
