# Utility Classes Reference

Recommended utility set for Rails CSS architecture.

---

## Recommended Utility Set

Keep the utility set small. Only add what you actually use.

```css
@layer utilities {
  /* === Spacing === */
  .m-0  { margin: 0; }
  .mt-1 { margin-top: var(--space-1); }
  .mt-2 { margin-top: var(--space-2); }
  .mt-3 { margin-top: var(--space-3); }
  .mt-4 { margin-top: var(--space-4); }
  .mt-6 { margin-top: var(--space-6); }
  .mt-8 { margin-top: var(--space-8); }
  .mb-2 { margin-bottom: var(--space-2); }
  .mb-4 { margin-bottom: var(--space-4); }
  .mb-6 { margin-bottom: var(--space-6); }
  .ml-auto { margin-left: auto; }
  .p-0  { padding: 0; }
  .p-2  { padding: var(--space-2); }
  .p-4  { padding: var(--space-4); }
  .p-6  { padding: var(--space-6); }
  .px-4 { padding-left: var(--space-4); padding-right: var(--space-4); }
  .py-2 { padding-top: var(--space-2); padding-bottom: var(--space-2); }
  .gap-2 { gap: var(--space-2); }
  .gap-3 { gap: var(--space-3); }
  .gap-4 { gap: var(--space-4); }
  .gap-6 { gap: var(--space-6); }

  /* === Typography === */
  .text-xs     { font-size: var(--text-xs); }
  .text-sm     { font-size: var(--text-sm); }
  .text-base   { font-size: var(--text-base); }
  .text-lg     { font-size: var(--text-lg); }
  .text-xl     { font-size: var(--text-xl); }
  .text-2xl    { font-size: var(--text-2xl); }
  .font-medium   { font-weight: var(--font-medium); }
  .font-semibold { font-weight: var(--font-semibold); }
  .font-bold     { font-weight: var(--font-bold); }
  .text-muted  { color: var(--color-ink-muted); }
  .text-subtle { color: var(--color-ink-subtle); }
  .text-center { text-align: center; }
  .text-right  { text-align: right; }
  .truncate    { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  /* === Layout === */
  .flex   { display: flex; }
  .grid   { display: grid; }
  .block  { display: block; }
  .inline { display: inline; }
  .inline-flex { display: inline-flex; }
  .hidden { display: none; }

  .items-center   { align-items: center; }
  .items-start    { align-items: flex-start; }
  .items-end      { align-items: flex-end; }
  .justify-center { justify-content: center; }
  .justify-between { justify-content: space-between; }
  .justify-end    { justify-content: flex-end; }
  .flex-col       { flex-direction: column; }
  .flex-wrap      { flex-wrap: wrap; }
  .flex-1         { flex: 1; }
  .flex-shrink-0  { flex-shrink: 0; }

  /* === Sizing === */
  .w-full { width: 100%; }
  .max-w-sm  { max-width: 24rem; }
  .max-w-md  { max-width: 28rem; }
  .max-w-lg  { max-width: 32rem; }
  .max-w-xl  { max-width: 36rem; }
  .max-w-2xl { max-width: 42rem; }

  /* === Borders === */
  .rounded     { border-radius: var(--radius-md); }
  .rounded-lg  { border-radius: var(--radius-lg); }
  .rounded-full { border-radius: var(--radius-full); }
  .border      { border: 1px solid var(--color-border); }
  .border-b    { border-bottom: 1px solid var(--color-border); }

  /* === Visibility === */
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border-width: 0;
  }
  .opacity-0   { opacity: 0; }
  .opacity-50  { opacity: 0.5; }
  .opacity-100 { opacity: 1; }

  /* === Position === */
  .relative { position: relative; }
  .absolute { position: absolute; }
  .sticky   { position: sticky; }
  .top-0    { top: 0; }
  .right-0  { right: 0; }
  .inset-0  { inset: 0; }

  /* === Misc === */
  .cursor-pointer { cursor: pointer; }
  .overflow-hidden { overflow: hidden; }
  .overflow-auto   { overflow: auto; }
}
```
