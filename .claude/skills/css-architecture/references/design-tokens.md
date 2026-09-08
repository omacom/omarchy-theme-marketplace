# Complete Design Token System

Detailed reference for the design token system — colors, spacing, typography, and more.

---

## Complete File Organization

### Directory Structure

```
app/assets/stylesheets/
├── _global.css              # Layer declarations + design tokens
├── application.css          # Entry point (imports or Rails manifest)
├── reset.css                # CSS reset
├── base.css                 # Element defaults (no classes)
├── utilities.css            # Single-purpose utility classes
├── components/
│   ├── app-layout.css       # Main layout shell (header, sidebar, main)
│   ├── forms.css            # Inputs, labels, buttons, form layout
│   ├── cards.css            # Card component + variants
│   ├── badges.css           # Badge variants
│   ├── alerts.css           # Alert/flash messages
│   ├── tables.css           # Table styles
│   ├── modals.css           # Modal/dialog patterns
│   ├── nav.css              # Navigation components
│   └── [feature].css        # Feature-specific components
└── pages/                   # Optional: page-specific layout (thin!)
    ├── dashboard.css
    └── settings.css
```

### What Goes Where

| File | Contains | Does NOT Contain |
|------|----------|------------------|
| `_global.css` | `@layer` declaration, `:root` tokens, raw palette | Component styles, classes |
| `reset.css` | Browser normalization | Design decisions |
| `base.css` | Element defaults (`body`, `h1-h6`, `a`, `input`) | Classes, component styles |
| `utilities.css` | Single-purpose `.mt-4`, `.hidden`, `.flex` | Multi-property classes |
| `components/*.css` | Reusable UI components | Page-specific overrides |
| `pages/*.css` | Page-specific layout grids | Component style overrides |

### application.css Entry Point

```css
/* application.css — if using CSS imports */
@import "_global.css";
@import "reset.css";
@import "base.css";
@import "components/app-layout.css";
@import "components/forms.css";
@import "components/cards.css";
@import "components/badges.css";
@import "components/alerts.css";
@import "components/tables.css";
@import "utilities.css";
```

---

## Raw Color Palette (OKLCH)

OKLCH provides perceptually uniform colors — equal lightness steps look equal to the human eye.

```css
:root {
  /* Zinc — neutral scale */
  --color-zinc-50:  oklch(0.985 0 0);
  --color-zinc-100: oklch(0.967 0.001 286.375);
  --color-zinc-200: oklch(0.92 0.004 286.32);
  --color-zinc-300: oklch(0.87 0.006 286.286);
  --color-zinc-400: oklch(0.707 0.022 261);
  --color-zinc-500: oklch(0.552 0.016 285.938);
  --color-zinc-600: oklch(0.442 0.017 285.786);
  --color-zinc-700: oklch(0.37 0.013 285.805);
  --color-zinc-800: oklch(0.274 0.006 286.033);
  --color-zinc-900: oklch(0.21 0.006 285.885);
  --color-zinc-950: oklch(0.141 0.005 285.823);

  /* Blue — primary/brand */
  --color-blue-50:  oklch(0.97 0.014 254);
  --color-blue-100: oklch(0.932 0.032 255);
  --color-blue-200: oklch(0.882 0.059 254);
  --color-blue-400: oklch(0.707 0.165 254.624);
  --color-blue-500: oklch(0.623 0.214 259.815);
  --color-blue-600: oklch(0.546 0.245 262.881);
  --color-blue-700: oklch(0.488 0.243 264.376);

  /* Green — positive/success */
  --color-green-50:  oklch(0.962 0.044 156);
  --color-green-500: oklch(0.586 0.154 149);
  --color-green-600: oklch(0.517 0.148 149);
  --color-green-800: oklch(0.345 0.108 148);
  --color-green-950: oklch(0.208 0.075 152);

  /* Red — negative/danger */
  --color-red-50:  oklch(0.971 0.013 17);
  --color-red-500: oklch(0.577 0.245 27.325);
  --color-red-600: oklch(0.528 0.229 25);
  --color-red-800: oklch(0.395 0.165 25);
  --color-red-950: oklch(0.258 0.092 26);

  /* Yellow — warning */
  --color-yellow-50:  oklch(0.987 0.026 102);
  --color-yellow-500: oklch(0.795 0.184 86);
  --color-yellow-600: oklch(0.681 0.162 75);
  --color-yellow-950: oklch(0.271 0.067 70);

  /* Purple — feature/accent (optional) */
  --color-purple-50:  oklch(0.977 0.014 308);
  --color-purple-500: oklch(0.553 0.235 303);
  --color-purple-600: oklch(0.496 0.265 301);
  --color-purple-950: oklch(0.224 0.114 303);
}
```

## Semantic Color Tokens

Semantic tokens map intent to palette values. Components only ever reference these.

```css
:root {
  color-scheme: light dark;

  /* === Surfaces (backgrounds) === */
  --color-canvas:          light-dark(var(--color-zinc-50), var(--color-zinc-900));
  --color-surface:         light-dark(white, var(--color-zinc-800));
  --color-surface-raised:  light-dark(white, var(--color-zinc-700));
  --color-surface-muted:   light-dark(var(--color-zinc-100), var(--color-zinc-800));
  --color-surface-overlay: light-dark(white, var(--color-zinc-800));

  /* === Ink (text) === */
  --color-ink:        light-dark(var(--color-zinc-900), var(--color-zinc-50));
  --color-ink-muted:  light-dark(var(--color-zinc-500), var(--color-zinc-400));
  --color-ink-subtle: light-dark(var(--color-zinc-400), var(--color-zinc-500));

  /* === Borders === */
  --color-border:        light-dark(var(--color-zinc-200), var(--color-zinc-700));
  --color-border-muted:  light-dark(var(--color-zinc-100), var(--color-zinc-800));
  --color-border-strong: light-dark(var(--color-zinc-400), var(--color-zinc-600));

  /* === Interactive === */
  --color-primary:       light-dark(var(--color-blue-600), var(--color-blue-500));
  --color-primary-hover: light-dark(var(--color-blue-700), var(--color-blue-400));
  --color-link:          light-dark(var(--color-blue-600), var(--color-blue-400));
  --color-focus-ring:    light-dark(var(--color-blue-200), var(--color-blue-700));

  /* === State: Positive === */
  --color-positive:        light-dark(var(--color-green-600), var(--color-green-500));
  --color-positive-canvas: light-dark(var(--color-green-50), var(--color-green-950));
  --color-positive-border: light-dark(var(--color-green-200), var(--color-green-800));

  /* === State: Negative === */
  --color-negative:        light-dark(var(--color-red-600), var(--color-red-500));
  --color-negative-canvas: light-dark(var(--color-red-50), var(--color-red-950));
  --color-negative-border: light-dark(var(--color-red-200), var(--color-red-800));

  /* === State: Warning === */
  --color-warning:        light-dark(var(--color-yellow-600), var(--color-yellow-500));
  --color-warning-canvas: light-dark(var(--color-yellow-50), var(--color-yellow-950));
  --color-warning-border: light-dark(var(--color-yellow-200), var(--color-yellow-800));
}
```

## Spacing Scale

```css
:root {
  --space-0:  0;
  --space-px: 1px;
  --space-0.5: 0.125rem;  /* 2px */
  --space-1:  0.25rem;    /* 4px */
  --space-1.5: 0.375rem;  /* 6px */
  --space-2:  0.5rem;     /* 8px */
  --space-3:  0.75rem;    /* 12px */
  --space-4:  1rem;       /* 16px */
  --space-5:  1.25rem;    /* 20px */
  --space-6:  1.5rem;     /* 24px */
  --space-8:  2rem;       /* 32px */
  --space-10: 2.5rem;     /* 40px */
  --space-12: 3rem;       /* 48px */
  --space-16: 4rem;       /* 64px */
  --space-20: 5rem;       /* 80px */
}
```

## Typography Scale

```css
:root {
  /* Font families */
  --font-sans: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --font-mono: ui-monospace, "SF Mono", "Cascadia Code", monospace;

  /* Sizes */
  --text-xs:   0.75rem;   /* 12px */
  --text-sm:   0.875rem;  /* 14px */
  --text-base: 1rem;      /* 16px */
  --text-lg:   1.125rem;  /* 18px */
  --text-xl:   1.25rem;   /* 20px */
  --text-2xl:  1.5rem;    /* 24px */
  --text-3xl:  1.875rem;  /* 30px */
  --text-4xl:  2.25rem;   /* 36px */

  /* Weights */
  --font-normal:   400;
  --font-medium:   500;
  --font-semibold: 600;
  --font-bold:     700;

  /* Line heights */
  --leading-tight:  1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.625;
}
```

## Border Radius and Transitions

```css
:root {
  /* Radii */
  --radius-sm:   0.25rem;  /* 4px */
  --radius-md:   0.375rem; /* 6px */
  --radius-lg:   0.5rem;   /* 8px */
  --radius-xl:   0.75rem;  /* 12px */
  --radius-2xl:  1rem;     /* 16px */
  --radius-full: 9999px;

  /* Transitions */
  --duration-fast:   150ms;
  --duration-normal: 250ms;
  --duration-slow:   350ms;
  --ease-out:  cubic-bezier(0.16, 1, 0.3, 1);
  --ease-in:   cubic-bezier(0.7, 0, 0.84, 0);

  /* Shadows (use sparingly — prefer borders in dark mode) */
  --shadow-sm: 0 1px 2px rgb(0 0 0 / 0.04);
  --shadow-md: 0 2px 4px rgb(0 0 0 / 0.06);
}
```

## Naming Convention Reference

| Pattern | Example | Use For |
|---------|---------|---------|
| `.component` | `.card`, `.btn`, `.badge` | Base component |
| `.component-sub` | `.card-header`, `.form-label` | Structural child |
| `.component-variant` | `.card-sm`, `.btn-primary` | Visual variant |
| `.is-state` | `.is-loading`, `.is-active` | Temporary state (global) |
| `.page-element` | `.dashboard-grid` | Page-specific layout |
| `.utility` | `.mt-4`, `.hidden`, `.flex` | Single-purpose override |

### Naming Rules

1. **No generic names** — `.container`, `.title`, `.item` WILL collide
2. **Prefix page-specific** — `.dashboard-grid`, `.settings-sidebar`
3. **Hyphenate everything** — `.card-header` not `.cardHeader` or `.card_header`
4. **Variants extend the base name** — `.btn-primary` not `.primary-btn`
5. **State classes start with `is-` or `has-`** — `.is-loading`, `.has-error`

## Checklists

### Adding a New Design Token

1. Add to `_global.css` under `:root`
2. For colors: use `light-dark()` with both mode values
3. For palette values: use OKLCH
4. Name semantically (`--color-surface-elevated`, not `--color-gray-lighter`)
5. Follow existing scale patterns (spacing, typography)
6. Document purpose with a comment if non-obvious
