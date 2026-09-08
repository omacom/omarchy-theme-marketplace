# Responsive Patterns

Mobile-first breakpoints, container queries, fluid typography, and common layout patterns.

---

## Mobile-First Breakpoints

```css
/* Base: mobile */
.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-4);
}

/* Tablet */
@media (min-width: 768px) {
  .dashboard-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-6);
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .dashboard-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

## Container Queries (Modern Alternative)

```css
.card-grid-container {
  container-type: inline-size;
}

.card-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-4);
}

@container (min-width: 600px) {
  .card-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 900px) {
  .card-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

## Fluid Typography

```css
:root {
  /* Fluid: 1rem at 320px, 1.25rem at 1280px */
  --text-fluid-base: clamp(1rem, 0.9rem + 0.26vw, 1.25rem);
  --text-fluid-lg: clamp(1.125rem, 1rem + 0.52vw, 1.5rem);
  --text-fluid-xl: clamp(1.5rem, 1.2rem + 1.04vw, 2.25rem);
}
```

## Common Layout Patterns

```css
/* Sidebar + main content */
@layer components {
  .app-layout {
    display: grid;
    grid-template-columns: 1fr;
    min-height: 100dvh;
  }

  @media (min-width: 768px) {
    .app-layout {
      grid-template-columns: 16rem 1fr;
    }
  }

  .app-sidebar {
    background: var(--color-surface);
    border-right: 1px solid var(--color-border);
    padding: var(--space-4);
  }

  .app-main {
    padding: var(--space-6);
    max-width: 80rem;
  }
}

/* Stack with consistent spacing */
.stack > * + * {
  margin-top: var(--space-4);
}

/* Cluster (flex wrap with gap) */
.cluster {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
  align-items: center;
}
```
