# CSS Layers Deep Dive

Using `@layer` to control the cascade without specificity wars.

---

## Layer Declaration and Priority

```css
/* _global.css — must be the very first rule */
@layer reset, base, components, utilities;
```

This declares cascade order. Rules in later layers beat earlier layers regardless of specificity.

```css
/* utilities layer always beats components, even if component has higher specificity */
@layer components {
  .card .title { color: red; }     /* Specificity: 0-2-0 */
}

@layer utilities {
  .text-blue { color: blue; }      /* Specificity: 0-1-0 — but WINS because layer is higher */
}
```

## Layer Assignment Patterns

**Inline (preferred for single files):**
```css
@layer components {
  .card { ... }
  .card-header { ... }
}
```

**Import-based (for large projects):**
```css
@import "reset.css" layer(reset);
@import "base.css" layer(base);
@import "components/cards.css" layer(components);
@import "utilities.css" layer(utilities);
```

## Unlayered CSS

CSS not in any layer has highest priority. Avoid this — it defeats the purpose of layers.

```css
/* This beats EVERYTHING, including utilities. Don't do this. */
.card { background: red; }

/* This respects the cascade properly */
@layer components {
  .card { background: var(--color-surface); }
}
```

## Third-Party CSS in Layers

Wrap third-party CSS in a layer to control its priority:

```css
@layer reset, vendor, base, components, utilities;

@import "normalize.css" layer(reset);
@import "some-library.css" layer(vendor);
```

## Anti-Pattern Examples

### ❌ Styling Components From Page CSS

```css
/* BAD — dashboard.css overriding card styles */
.dashboard .card { padding: 2rem; }
.dashboard .card .title { font-size: 24px; }

/* GOOD — card variant in cards.css */
.card-lg { padding: var(--space-8); }
.card-title-lg { font-size: var(--text-2xl); }
```

### ❌ Deep Nesting

```css
/* BAD */
.dashboard .sidebar .nav .item .link { color: blue; }

/* GOOD */
.nav-link { color: var(--color-link); }
```

### ❌ Using !important

```css
/* BAD */
.card { padding: 2rem !important; }

/* GOOD — use @layer */
@layer utilities {
  .p-8 { padding: var(--space-8); }
}
```

### ❌ Inline Styles in ERB

```erb
<%# BAD %>
<div style="margin-top: 16px; padding: 24px; background: white;">

<%# GOOD %>
<div class="card mt-4">
```

### ❌ Framework-Dependent Markup

```erb
<%# BAD — tightly coupled to Tailwind %>
<div class="bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-lg p-6">

<%# GOOD — semantic classes, framework-free %>
<div class="card">
```

### ❌ Magic Numbers

```css
/* BAD */
.card { padding: 23px; margin-top: 17px; border-radius: 7px; }

/* GOOD */
.card { padding: var(--space-6); margin-top: var(--space-4); border-radius: var(--radius-lg); }
```

### ❌ Raw Colors in Components

```css
/* BAD */
.alert-success { background: #dcfce7; color: #166534; }

/* GOOD */
.alert-success { background: var(--color-positive-canvas); color: var(--color-positive); }
```
