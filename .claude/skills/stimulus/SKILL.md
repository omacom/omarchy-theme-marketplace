---
name: stimulus
description: Expert guidance for building Stimulus controllers in Rails applications. Use when creating JavaScript behaviors, writing data-controller/data-action/data-target attributes, building interactive UI components, or working with Hotwire Stimulus. Covers controller creation, targets, values, actions, classes, outlets, lifecycle callbacks, progressive enhancement, and common patterns like clipboard, flash, modal, toggle, and form validation.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate stimulus *), Bash(bin/rails stimulus:manifest:update)
---

# Rails Stimulus Expert

Build small, focused JavaScript controllers that connect HTML to behavior through data attributes.

## Philosophy

**Core Principles:**
1. **HTML-first** — Stimulus enhances server-rendered HTML, it doesn't replace it
2. **Small controllers** — One controller = one behavior. Compose by stacking controllers on elements
3. **Progressive enhancement** — Pages must work without JavaScript; controllers add interactivity
4. **No rendering in JS** — Controllers manipulate DOM state (classes, attributes, visibility), never build HTML strings
5. **Convention over configuration** — Data attributes wire everything; no manual event binding

**The Stimulus Mental Model:**
```
HTML (data attributes)  →  Controller (JS behavior)  →  DOM changes (classes, text, visibility)
     ↑ source of truth        ↑ small & focused            ↑ CSS does the heavy lifting
```

## When To Use This Skill

- Creating new Stimulus controllers
- Connecting controllers to HTML via data attributes
- Adding interactivity to server-rendered views (toggles, modals, clipboard, flash, forms)
- Debugging controller connection issues
- Organizing controller files and imports
- Using values, targets, classes, outlets, and lifecycle callbacks
- Cross-controller communication via outlets or custom events

## Instructions

### Step 1: Check Existing Controllers

**ALWAYS search for existing controllers before creating new ones:**

```bash
# List all controllers
ls app/javascript/controllers/

# Search for similar behavior
rg "static targets" app/javascript/controllers/
rg "static values" app/javascript/controllers/

# Check if there's a matching controller already
rg "data-controller=\"toggle\"" app/views/
```

**Match existing project conventions** — naming, style, patterns. Consistency beats "ideal."

### Step 2: Generate or Create the Controller

**Use the Rails generator:**

```bash
bin/rails generate stimulus example
# Creates: app/javascript/controllers/example_controller.js
# Updates: app/javascript/controllers/index.js (if not using auto-loading)
```

**Or create manually:**

```javascript
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
  }
}
```

Controllers in `app/javascript/controllers/` are auto-registered via `index.js`:

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

### Step 3: Define the Controller Interface

Declare targets, values, classes, and outlets **statically at the top**:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output", "submit"]
  static values = {
    url: String,
    count: { type: Number, default: 0 },
    enabled: Boolean,
    items: Array,
    config: Object
  }
  static classes = ["active", "loading", "hidden"]
  static outlets = ["other-controller"]

  // Lifecycle, then actions
  connect() { }
  disconnect() { }

  // Action methods
  toggle() { }
  submit() { }
}
```

**Order convention:** static declarations → lifecycle → actions → private helpers.

### Step 4: Wire Up HTML with Data Attributes

**⚠️ CRITICAL: Data attribute naming is the #1 source of bugs.**

The rules:
- Controller names: **kebab-case** in HTML (`data-controller="my-thing"`), **snake_case** filenames (`my_thing_controller.js`), **camelCase** never appears in HTML
- Multi-word values: **kebab-case** in HTML attributes, **camelCase** in JavaScript access
- Target attribute format: `data-{controller}-target="{name}"`
- Value attribute format: `data-{controller}-{name}-value="{val}"`
- Class attribute format: `data-{controller}-{class}-class="{css-class}"`
- Action format: `data-action="{event}->{controller}#{method}"`

```erb
<%# Controller with values, targets, and actions %>
<div data-controller="search"
     data-search-url-value="<%= search_path %>"
     data-search-debounce-value="300"
     data-search-active-class="is-active">

  <input data-search-target="input"
         data-action="input->search#query keydown.escape->search#clear"
         type="text"
         placeholder="Search...">

  <div data-search-target="results"></div>
</div>
```

**Common naming mistakes agents make:**

```erb
<%# WRONG — camelCase in HTML attribute %>
<div data-controller="myThing">
<div data-myThing-url-value="/api">

<%# CORRECT — kebab-case in HTML %>
<div data-controller="my-thing">
<div data-my-thing-url-value="/api">

<%# WRONG — wrong target format %>
<div data-target="search.input">

<%# CORRECT — namespaced target format %>
<div data-search-target="input">
```

### Step 5: Handle Actions Correctly

**Default events (can omit event name):**

| Element | Default Event |
|---------|--------------|
| `<button>` | `click` |
| `<input>` | `input` |
| `<select>` | `change` |
| `<form>` | `submit` |
| `<a>` | `click` |
| `<textarea>` | `input` |
| `<details>` | `toggle` |

```erb
<%# These are equivalent for a button: %>
<button data-action="click->toggle#flip">Toggle</button>
<button data-action="toggle#flip">Toggle</button>

<%# Multiple actions on one element: %>
<input data-action="input->search#query focus->search#expand blur->search#collapse">

<%# Keyboard modifiers: %>
<input data-action="keydown.enter->form#submit keydown.escape->form#cancel">

<%# Event options: %>
<a data-action="click->nav#toggle:prevent">Link</a>
<button data-action="click->menu#close:stop">Close</button>
<div data-action="scroll->lazy#load:once">Load once</div>
```

**Available key modifiers:** `enter`, `tab`, `esc`, `space`, `up`, `down`, `left`, `right`, `home`, `end`, plus any `KeyboardEvent.key` value.

**Action options:** `:prevent` (preventDefault), `:stop` (stopPropagation), `:once` (remove after first call), `:self` (only if event.target is the element itself).

### Step 6: Use Lifecycle Callbacks

```javascript
export default class extends Controller {
  // Called once when controller class is first instantiated
  // Use for: one-time setup like binding methods for callbacks
  initialize() {
    this.search = this.search.bind(this)
  }

  // Called every time the controller's element enters the DOM
  // Use for: setting up timers, observers, fetching initial data
  connect() {
    this.interval = setInterval(() => this.poll(), 5000)
  }

  // Called every time the controller's element leaves the DOM
  // Use for: cleanup! Timers, observers, event listeners
  disconnect() {
    clearInterval(this.interval)
  }

  // Target connected/disconnected callbacks
  outputTargetConnected(element) {
    // Called when a new output target appears in DOM
  }

  outputTargetDisconnected(element) {
    // Called when an output target is removed from DOM
  }

  // Value change callbacks
  countValueChanged(newValue, oldValue) {
    this.outputTarget.textContent = newValue
  }
}
```

**⚠️ Always clean up in `disconnect()`.** Stimulus controllers connect/disconnect as DOM changes (Turbo navigation, Turbo Streams, etc.). Leaked timers and observers are the most common Stimulus bug.

### Step 7: Keep Controllers Small

**One behavior per controller. Compose by stacking.**

```erb
<%# Good — two focused controllers %>
<div data-controller="dropdown tooltip">
  <button data-action="click->dropdown#toggle mouseenter->tooltip#show mouseleave->tooltip#hide">
    Options
  </button>
</div>

<%# Bad — one mega-controller doing everything %>
<div data-controller="dropdown-with-tooltip-and-keyboard-nav">
```

**If a controller exceeds ~80 lines, it's probably doing too much.** Split it.

### Step 8: Use CSS for Visual State

Controllers toggle classes. CSS does the rendering.

```javascript
// Good — controller manages state
toggle() {
  this.element.classList.toggle(this.activeClass)
}

// Bad — controller manages appearance
toggle() {
  this.element.style.display = this.element.style.display === "none" ? "block" : "none"
  this.element.style.opacity = "1"
  this.element.style.transform = "translateY(0)"
}
```

```css
/* CSS handles all visual transitions */
.dropdown { display: none; }
.dropdown.is-active { display: block; }
```

### Step 9: Use Outlets for Cross-Controller Communication

Outlets let one controller reference and call methods on another:

```javascript
// tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["panel"]

  select(event) {
    const index = event.currentTarget.dataset.index
    this.panelOutlets.forEach((panel, i) => {
      panel.toggle(i === parseInt(index))
    })
  }
}
```

```erb
<div data-controller="tabs" data-tabs-panel-outlet=".tab-panel">
  <button data-action="click->tabs#select" data-index="0">Tab 1</button>
  <button data-action="click->tabs#select" data-index="1">Tab 2</button>

  <div class="tab-panel" data-controller="panel">Content 1</div>
  <div class="tab-panel" data-controller="panel">Content 2</div>
</div>
```

**Outlet naming:** kebab-case controller name in `data-{controller}-{outlet-name}-outlet` attribute. The outlet value is a **CSS selector** that matches elements with the target controller.

**Alternative: Custom Events** — for looser coupling when outlets feel too tight:

```javascript
// Dispatching controller
this.dispatch("selected", { detail: { index: 0 } })

// Listening in HTML
<div data-action="tabs:selected->panel#activate">
```

### Step 10: Debugging

```javascript
// Enable debug mode in browser console
Stimulus.debug = true
// Shows: connect/disconnect events, action dispatches, value changes

// Add logging in connect() for troubleshooting
connect() {
  console.log(`${this.identifier} connected`, this.element)
  console.log("targets:", this.outputTargets)
  console.log("values:", this.urlValue, this.countValue)
}
```

**Common issues:**
1. **Controller not connecting** → Check: typo in `data-controller`, file naming (`snake_case_controller.js`), controller registered in `index.js`
2. **Target not found** → Check: target element is *inside* the controller's element, correct `data-{controller}-target` format
3. **Action not firing** → Check: `data-action` format is `event->controller#method`, method exists and isn't a typo
4. **Values not updating** → Check: `data-{controller}-{name}-value` format, value type matches static declaration
5. **Controller disconnects unexpectedly** → Turbo navigation replaced the DOM. Make sure controller element persists or re-attaches properly.

## Quick Reference

### Accessing Targets

```javascript
this.outputTarget          // First matching target (throws if missing)
this.outputTargets         // Array of all matching targets
this.hasOutputTarget       // Boolean — does at least one exist?
```

### Accessing Values

```javascript
this.urlValue              // Get
this.urlValue = "/new"     // Set (triggers valueChanged callback)
this.hasUrlValue           // Boolean — was it specified in HTML?
```

### Accessing Classes

```javascript
this.activeClass           // Single class string, e.g. "is-active"
this.activeClasses         // Array of classes
this.hasActiveClass        // Boolean
```

### Accessing Outlets

```javascript
this.panelOutlet           // First matching outlet controller
this.panelOutlets          // Array of all matching outlet controllers
this.hasPanelOutlet        // Boolean
this.panelOutletElement    // The DOM element of the first outlet
this.panelOutletElements   // Array of DOM elements
```

### Value Types

| Type | HTML Example | JS Default |
|------|-------------|------------|
| `String` | `data-x-name-value="hello"` | `""` |
| `Number` | `data-x-count-value="5"` | `0` |
| `Boolean` | `data-x-open-value="true"` | `false` |
| `Array` | `data-x-items-value='["a","b"]'` | `[]` |
| `Object` | `data-x-config-value='{"k":"v"}'` | `{}` |

### File Organization

```
app/javascript/
├── application.js                    # Entry point, imports controllers
├── controllers/
│   ├── application.js                # Base controller (extend this)
│   ├── index.js                      # Auto-loader registration
│   ├── clipboard_controller.js       # Simple, focused controllers
│   ├── dropdown_controller.js
│   ├── flash_controller.js
│   ├── modal_controller.js
│   ├── toggle_controller.js
│   └── form_validation_controller.js
```

**Naming:** `{behavior}_controller.js` — name by what it *does*, not what it's *for*.
- ✅ `toggle_controller.js`, `clipboard_controller.js`, `auto_submit_controller.js`
- ❌ `sidebar_controller.js`, `header_controller.js`, `user_form_controller.js`

## Common Patterns

See `reference.md` for complete implementations of:
- Clipboard copy with visual feedback
- Auto-dismissing flash messages
- Modal dialogs (with `<dialog>`)
- Toggle/disclosure
- Form validation
- Debounced search
- Character counter
- Auto-submit forms
- Nested/namespaced controllers

## Anti-Patterns to Avoid

1. **Mega-controllers** — If it's > 80 lines, split it into composable pieces
2. **Rendering HTML in JS** — Use Turbo Streams for dynamic content; Stimulus just toggles state
3. **Direct style manipulation** — Toggle classes, let CSS handle appearance
4. **Forgetting disconnect cleanup** — Every `setInterval`, `addEventListener`, `MutationObserver` in `connect()` needs cleanup in `disconnect()`
5. **camelCase in HTML attributes** — Always kebab-case: `data-my-thing-url-value`, not `data-myThing-url-value`
6. **Reaching outside the controller element** — Use outlets or events for cross-controller communication, don't `document.querySelector` from inside a controller
7. **Business logic in controllers** — Keep controllers thin; complex logic belongs on the server
8. **Not using values for configuration** — Don't hardcode URLs, durations, or thresholds; use values so HTML can configure behavior
