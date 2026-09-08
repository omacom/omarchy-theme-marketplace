# Stimulus Reference

Detailed patterns, complete examples, and edge cases for Stimulus controllers in Rails.

## Table of Contents
- [Data Attribute Naming Rules](#data-attribute-naming-rules)
- [Controller Patterns](#controller-patterns)
- [Lifecycle Deep Dive](#lifecycle-deep-dive)
- [Outlets In Depth](#outlets-in-depth)
- [Working with Turbo](#working-with-turbo)
- [Rails View Helpers and Stimulus](#rails-view-helpers-and-stimulus)
- [Advanced Patterns](#advanced-patterns)
- [Import Maps vs. Bundler](#import-maps-vs-bundler)
- [Testing Stimulus Controllers](#testing-stimulus-controllers)
- [Troubleshooting Checklist](#troubleshooting-checklist)

## Data Attribute Naming Rules

This is the single most error-prone area. Memorize these rules.

### Controller Names

| Context | Format | Example |
|---------|--------|---------|
| HTML attribute | kebab-case | `data-controller="content-loader"` |
| Filename | snake_case | `content_loader_controller.js` |
| JS class | PascalCase (auto) | `ContentLoaderController` (you never write this) |

### Multi-Word Attributes

```erb
<%# Controller: "content-loader" %>
<%# Value named "apiUrl" in JS → "api-url" in HTML %>
<div data-controller="content-loader"
     data-content-loader-api-url-value="/api/items"
     data-content-loader-refresh-interval-value="5000">
```

```javascript
// In the controller:
static values = { apiUrl: String, refreshInterval: Number }
// Access:
this.apiUrlValue           // "/api/items"
this.refreshIntervalValue  // 5000
```

**The pattern:** JS uses camelCase (`apiUrl`), HTML uses kebab-case (`api-url`), prefixed with controller name (`content-loader-api-url-value`).

### Complete Attribute Format Table

| Feature | HTML Attribute | JS Access |
|---------|---------------|-----------|
| Controller | `data-controller="name"` | `this.identifier` |
| Target | `data-name-target="foo"` | `this.fooTarget` |
| Value | `data-name-foo-value="x"` | `this.fooValue` |
| Class | `data-name-foo-class="x"` | `this.fooClass` |
| Action | `data-action="event->name#method"` | N/A (auto-wired) |
| Outlet | `data-name-other-outlet=".sel"` | `this.otherOutlet` |

## Controller Patterns

### Clipboard Copy with Visual Feedback

```javascript
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static values = { successDuration: { type: Number, default: 1500 } }

  copy(event) {
    const text = this.hasSourceTarget
      ? this.sourceTarget.value || this.sourceTarget.textContent
      : this.element.dataset.clipboardText

    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback(event.currentTarget)
    })
  }

  showFeedback(button) {
    const original = button.textContent
    button.textContent = "Copied!"
    button.disabled = true

    setTimeout(() => {
      button.textContent = original
      button.disabled = false
    }, this.successDurationValue)
  }
}
```

```erb
<%# Simple — text from data attribute %>
<button data-controller="clipboard"
        data-clipboard-text="<%= @api_key %>"
        data-action="click->clipboard#copy">
  Copy API Key
</button>

<%# With source target — copies from input %>
<div data-controller="clipboard">
  <input data-clipboard-target="source" value="<%= @token %>" readonly>
  <button data-action="click->clipboard#copy">Copy</button>
</div>
```

### Auto-Dismissing Flash Messages

```javascript
// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = {
    autoDismiss: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }
  static classes = ["dismissing"]

  connect() {
    if (this.autoDismissValue) {
      this.messageTargets.forEach((msg) => {
        setTimeout(() => this.dismissMessage(msg), this.delayValue)
      })
    }
  }

  dismiss(event) {
    const message = event.target.closest("[data-flash-target='message']")
    if (message) this.dismissMessage(message)
  }

  dismissMessage(message) {
    if (this.hasDismissingClass) {
      message.classList.add(this.dismissingClass)
    }

    // Allow CSS transition to complete before removing
    message.addEventListener("transitionend", () => message.remove(), { once: true })

    // Fallback if no CSS transition
    setTimeout(() => {
      if (message.parentNode) message.remove()
    }, 300)

    // Clean up container if empty
    setTimeout(() => {
      if (this.element.children.length === 0) this.element.remove()
    }, 350)
  }
}
```

```erb
<div data-controller="flash"
     data-flash-delay-value="5000"
     data-flash-dismissing-class="flash--dismissing">
  <% flash.each do |type, message| %>
    <div class="flash flash--<%= type %>" data-flash-target="message">
      <span><%= message %></span>
      <button data-action="click->flash#dismiss" aria-label="Dismiss">&times;</button>
    </div>
  <% end %>
</div>
```

```css
.flash { transition: opacity 0.2s ease-out, transform 0.2s ease-out; }
.flash--dismissing { opacity: 0; transform: translateX(100%); }
```

### Modal Dialog (using `<dialog>`)

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
    document.body.style.overflow = "hidden"
  }

  close() {
    this.dialogTarget.close()
    document.body.style.overflow = ""
  }

  // Close when clicking the backdrop (the dialog element itself, not its content)
  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  disconnect() {
    document.body.style.overflow = ""
  }
}
```

```erb
<div data-controller="modal">
  <button data-action="click->modal#open">Open Modal</button>

  <dialog data-modal-target="dialog"
          data-action="click->modal#clickOutside">
    <div class="modal-content">
      <h2>Modal Title</h2>
      <p>Modal content here.</p>
      <button data-action="click->modal#close">Close</button>
    </div>
  </dialog>
</div>
```

**Note:** `<dialog>` has built-in Escape key handling. No need to add a `keydown` listener for that.

### Toggle / Disclosure

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static classes = ["hidden"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.sync()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  show() {
    this.openValue = true
  }

  hide() {
    this.openValue = false
  }

  openValueChanged() {
    this.sync()
  }

  sync() {
    this.contentTargets.forEach((el) => {
      el.classList.toggle(this.hiddenClass, !this.openValue)
    })
  }
}
```

```erb
<div data-controller="toggle"
     data-toggle-hidden-class="hidden"
     data-toggle-open-value="false">
  <button data-action="click->toggle#toggle">
    Show Details
  </button>
  <div data-toggle-target="content">
    <p>Hidden content here.</p>
  </div>
</div>
```

### Toggle Password Visibility

```javascript
// app/javascript/controllers/visibility_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"

    if (this.hasIconTarget) {
      this.iconTarget.textContent = isPassword ? "🙈" : "👁"
    }
  }
}
```

```erb
<div data-controller="visibility">
  <%= password_field_tag :password, nil,
        data: { visibility_target: "input" } %>
  <button type="button" data-action="click->visibility#toggle">
    <span data-visibility-target="icon">👁</span>
  </button>
</div>
```

### Debounced Search

```javascript
// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = {
    url: String,
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  query() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchResults()
    }, this.debounceValue)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (query.length === 0) {
      this.resultsTarget.innerHTML = ""
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    const response = await fetch(url, {
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      }
    })

    if (response.ok) {
      const html = await response.text()
      this.resultsTarget.innerHTML = html
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

```erb
<div data-controller="search"
     data-search-url-value="<%= search_path %>"
     data-search-debounce-value="300">
  <input data-search-target="input"
         data-action="input->search#query"
         type="search"
         placeholder="Search...">
  <div data-search-target="results"></div>
</div>
```

### Character Counter

```javascript
// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }
  static classes = ["over"]

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value.length
    const remaining = this.maxValue - length
    this.countTarget.textContent = `${remaining} characters remaining`

    if (this.hasOverClass) {
      this.countTarget.classList.toggle(this.overClass, remaining < 0)
    }
  }
}
```

```erb
<div data-controller="character-counter"
     data-character-counter-max-value="280"
     data-character-counter-over-class="text-red-500">
  <textarea data-character-counter-target="input"
            data-action="input->character-counter#update"></textarea>
  <span data-character-counter-target="count"></span>
</div>
```

### Auto-Submit Form

```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.timeout = null
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

```erb
<%= form_with url: search_path, method: :get, data: {
      controller: "auto-submit",
      auto_submit_delay_value: 500
    } do |f| %>
  <%= f.text_field :q, data: { action: "input->auto-submit#submit" } %>
<% end %>
```

### Form Validation (Client-Side Enhancement)

```javascript
// app/javascript/controllers/form_validation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  validate(event) {
    const input = event.target
    const isValid = input.checkValidity()

    // Show/hide browser validation message
    if (!isValid) {
      input.reportValidity()
    }

    // Optionally disable submit until valid
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !this.element.checkValidity()
    }
  }

  preventInvalid(event) {
    if (!this.element.checkValidity()) {
      event.preventDefault()
      // Focus first invalid field
      this.element.querySelector(":invalid")?.focus()
    }
  }
}
```

```erb
<%= form_with model: @post, data: {
      controller: "form-validation",
      action: "submit->form-validation#preventInvalid"
    } do |f| %>
  <%= f.text_field :title, required: true,
        data: { action: "blur->form-validation#validate" } %>
  <%= f.submit "Save", data: { form_validation_target: "submit" } %>
<% end %>
```

## Lifecycle Deep Dive

### Execution Order

```
1. initialize()                      — once per controller instance
2. [connect()]                       — element enters DOM
3. [{name}TargetConnected(el)]       — each target enters DOM
4. [{name}ValueChanged(new, old)]    — values parsed from HTML
5. ... (user interactions, actions)
6. [{name}TargetDisconnected(el)]    — target leaves DOM
7. [disconnect()]                    — element leaves DOM
```

### Target Callbacks

```javascript
export default class extends Controller {
  static targets = ["item"]

  // Called for EACH item target when it connects
  itemTargetConnected(element) {
    console.log("Item added:", element)
    this.updateCount()
  }

  // Called for EACH item target when it disconnects
  itemTargetDisconnected(element) {
    console.log("Item removed:", element)
    this.updateCount()
  }

  updateCount() {
    console.log(`Total items: ${this.itemTargets.length}`)
  }
}
```

This is particularly useful with Turbo Streams that add/remove elements dynamically.

### Value Change Callbacks

```javascript
export default class extends Controller {
  static values = {
    count: { type: Number, default: 0 },
    url: String
  }

  // Called when countValue changes (including initial parse from HTML)
  countValueChanged(newValue, oldValue) {
    // oldValue is undefined on first call (initial parse)
    if (oldValue !== undefined) {
      console.log(`Count changed from ${oldValue} to ${newValue}`)
    }
  }

  // Called when urlValue changes
  urlValueChanged() {
    this.fetchData()
  }
}
```

## Outlets In Depth

### Declaring and Using Outlets

```javascript
// parent_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["child"]

  notifyAll() {
    this.childOutlets.forEach(child => child.refresh())
  }

  // Outlet connected/disconnected callbacks
  childOutletConnected(outlet, element) {
    console.log("Child connected:", element)
  }

  childOutletDisconnected(outlet, element) {
    console.log("Child disconnected:", element)
  }
}
```

```erb
<%# The outlet selector is a CSS selector that matches elements with the child controller %>
<div data-controller="parent"
     data-parent-child-outlet=".child-item">

  <div class="child-item" data-controller="child">Item 1</div>
  <div class="child-item" data-controller="child">Item 2</div>
</div>
```

**Key rules:**
- The outlet selector must match elements that *have* the target controller attached
- Outlets can reference controllers outside the parent's DOM subtree
- Outlet elements must be in the DOM when the parent connects (or use `childOutletConnected` callback)

### Outlet vs. Custom Events

**Use outlets when:**
- Parent needs to call specific methods on children
- Relationship is explicit and structural
- You need typed references to controller instances

**Use custom events when:**
- Communication is one-to-many or loosely coupled
- Controllers don't know about each other
- Events bubble up naturally

```javascript
// Dispatching events
this.dispatch("change", {
  detail: { value: this.countValue },
  prefix: "filter"  // event name becomes "filter:change"
})

// Listening via data-action
// <div data-action="filter:change->results#update">
```

## Working with Turbo

### Stimulus + Turbo Frames

Controllers inside Turbo Frames reconnect automatically when the frame is replaced:

```erb
<%= turbo_frame_tag "notifications" do %>
  <div data-controller="flash" data-flash-delay-value="3000">
    <%# This controller will reconnect when the frame reloads %>
  </div>
<% end %>
```

### Stimulus + Turbo Streams

Turbo Streams can add/remove elements with controllers attached. Use target callbacks to react:

```javascript
export default class extends Controller {
  static targets = ["item"]

  // Automatically called when Turbo Stream appends a new item
  itemTargetConnected(element) {
    this.animateIn(element)
  }
}
```

### Preserving State Across Turbo Navigations

If you need state to survive Turbo Drive navigations, store it outside the controller:

```javascript
export default class extends Controller {
  connect() {
    // Restore from sessionStorage
    this.element.value = sessionStorage.getItem("search-query") || ""
  }

  save() {
    sessionStorage.setItem("search-query", this.element.value)
  }

  disconnect() {
    this.save()
  }
}
```

## Rails View Helpers and Stimulus

### Using data attributes in Rails helpers

```erb
<%# form_with %>
<%= form_with model: @post, data: {
      controller: "auto-save",
      auto_save_url_value: auto_save_post_path(@post),
      action: "input->auto-save#save"
    } do |f| %>

<%# text_field with target and action %>
<%= f.text_field :title, data: {
      auto_save_target: "input",
      action: "blur->auto-save#save"
    } %>

<%# link_to with action %>
<%= link_to "Delete", post_path(@post), data: {
      turbo_method: :delete,
      turbo_confirm: "Are you sure?",
      action: "click->analytics#track"
    } %>

<%# button_tag %>
<%= button_tag "Submit", data: {
      action: "click->form#submit"
    } %>

<%# content_tag / tag helper %>
<%= tag.div data: {
      controller: "toggle",
      toggle_open_value: false,
      toggle_hidden_class: "hidden"
    } do %>
  Content here
<% end %>
```

**⚠️ Rails data hash gotcha:** Rails converts underscores to dashes in data attribute keys. `data: { auto_save_target: "input" }` becomes `data-auto-save-target="input"`. This is what you want! But be aware:

```ruby
# This works (underscores → dashes):
data: { my_controller_url_value: "/api" }
# Produces: data-my-controller-url-value="/api" ✅

# This does NOT work (double-nested hash):
data: { my_controller: { url_value: "/api" } }
# Produces: data-my-controller='{"url_value":"/api"}' ❌
```

## Advanced Patterns

### Extending the Application Controller

```javascript
// app/javascript/controllers/application.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Shared helpers available to all controllers
  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content
  }

  async fetchWithCsrf(url, options = {}) {
    return fetch(url, {
      ...options,
      headers: {
        "X-CSRF-Token": this.csrfToken,
        ...options.headers
      }
    })
  }
}
```

```javascript
// Other controllers extend from application.js, not @hotwired/stimulus
import ApplicationController from "./application"

export default class extends ApplicationController {
  async submit() {
    await this.fetchWithCsrf(this.urlValue, { method: "POST" })
  }
}
```

### Namespaced Controllers (Subdirectories)

```
app/javascript/controllers/
├── admin/
│   └── dashboard_controller.js
└── shared/
    └── dropdown_controller.js
```

```erb
<%# Subdirectory becomes namespace with double-dash separator %>
<div data-controller="admin--dashboard">
<div data-controller="shared--dropdown">
```

### Global/Window Event Listeners

```javascript
export default class extends Controller {
  connect() {
    // Use bound method for cleanup
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
  }

  handleResize() {
    // Respond to window resize
  }
}
```

**Alternative: Use `@window` and `@document` action targets:**

```erb
<%# Stimulus handles listener cleanup automatically with this syntax %>
<div data-controller="responsive"
     data-action="resize@window->responsive#layout
                  keydown.escape@document->responsive#close">
</div>
```

This is cleaner and Stimulus handles the cleanup — prefer this over manual `addEventListener`.

### Third-Party Library Integration

```javascript
import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static values = { options: { type: Object, default: {} } }

  connect() {
    this.picker = flatpickr(this.element, {
      ...this.optionsValue,
      onChange: this.handleChange.bind(this)
    })
  }

  disconnect() {
    this.picker.destroy()
  }

  handleChange(dates) {
    this.dispatch("change", { detail: { dates } })
  }
}
```

```erb
<input data-controller="datepicker"
       data-datepicker-options-value='{"enableTime": true, "dateFormat": "Y-m-d H:i"}'>
```

## Import Maps vs. Bundler

### With Import Maps (Rails default)

```bash
# Pin Stimulus (done automatically by Rails)
bin/importmap pin @hotwired/stimulus @hotwired/stimulus-loading

# Pin third-party packages
bin/importmap pin flatpickr
```

```ruby
# config/importmap.rb
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
```

### With a Bundler (esbuild, Bun, etc.)

```bash
# Install packages
yarn add @hotwired/stimulus
# or
bun add @hotwired/stimulus
```

Controller auto-loading works the same way via `stimulus-loading`.

## Testing Stimulus Controllers

### System Tests (Full Integration)

```ruby
class ToggleSystemTest < ApplicationSystemTestCase
  test "toggle shows and hides content" do
    visit page_path

    assert_no_selector ".details-content:not(.hidden)"

    click_on "Show Details"
    assert_selector ".details-content:not(.hidden)"

    click_on "Show Details"
    assert_selector ".details-content.hidden"
  end
end
```

### Request Tests (Verify HTML Attributes)

```ruby
class PostsRequestTest < ActionDispatch::IntegrationTest
  test "edit form includes stimulus controller" do
    get edit_post_path(@post)
    assert_select "[data-controller='auto-save']"
    assert_select "[data-auto-save-url-value]"
  end
end
```

### JavaScript Unit Tests (Optional)

For complex controllers, consider testing with a JS test framework:

```javascript
// test/javascript/controllers/character_counter_controller.test.js
import { Application } from "@hotwired/stimulus"
import CharacterCounterController from "controllers/character_counter_controller"

describe("CharacterCounterController", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="character-counter" data-character-counter-max-value="10">
        <input data-character-counter-target="input">
        <span data-character-counter-target="count"></span>
      </div>
    `
    const app = Application.start()
    app.register("character-counter", CharacterCounterController)
  })

  it("shows remaining characters", () => {
    const input = document.querySelector("input")
    const count = document.querySelector("span")

    input.value = "hello"
    input.dispatchEvent(new Event("input"))

    expect(count.textContent).toContain("5 characters remaining")
  })
})
```

## Troubleshooting Checklist

### Controller Not Connecting

1. **File exists?** `ls app/javascript/controllers/{name}_controller.js`
2. **Registered?** Check `app/javascript/controllers/index.js` or run `bin/rails stimulus:manifest:update`
3. **Filename matches?** HTML `data-controller="content-loader"` → file `content_loader_controller.js`
4. **Syntax error?** Check browser console for import/parse errors
5. **Inside Turbo Frame?** Controller element might be outside the frame that loaded

### Target Not Found Error

1. **Inside controller element?** Target must be a descendant of `data-controller` element
2. **Correct format?** `data-{controller}-target="name"` (not `data-target`)
3. **Typo in name?** Must match exactly what's in `static targets = [...]`
4. **Dynamic content?** If added via Turbo Stream, use `{name}TargetConnected` callback

### Value Not Updating

1. **Correct format?** `data-{controller}-{name}-value="x"`
2. **Type mismatch?** Number value with non-numeric string silently defaults
3. **Array/Object values** must be valid JSON: `data-x-items-value='["a","b"]'` (single quotes around, double quotes inside)
4. **Boolean values** are strings: `data-x-enabled-value="true"` (not bare `true`)

### Actions Not Firing

1. **Format correct?** `data-action="event->controller#method"`
2. **Method exists?** Must be a method on the controller class (not a property)
3. **Event name right?** `click`, `input`, `change`, `submit` — not `onclick` or `oninput`
4. **Modifier syntax?** `.enter` not `:enter` for key filters: `keydown.enter->form#submit`
5. **Default event assumed?** Only works for standard elements (button→click, form→submit, etc.)

### Memory Leaks / Stale State

1. **Cleaning up in disconnect()?** Every interval, observer, and global listener needs cleanup
2. **Turbo navigation replacing DOM?** Your controller disconnects and reconnects — state resets
3. **Using `@window`/`@document` actions?** Stimulus auto-cleans these. Prefer over manual listeners.
