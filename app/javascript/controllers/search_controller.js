import { Controller } from "@hotwired/stimulus"

// Submits the search form (a GET that targets the gallery Turbo Frame) as the user types.
// Before submitting, copies the gallery's current filter/sort/colour into the hidden fields so a
// search never resets what the user picked.
export default class extends Controller {
  static targets = ["filter", "sort", "color"]
  static values = { delay: { type: Number, default: 200 } }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const state = document.getElementById("gallery-state")
      if (state) {
        for (const [target, key] of [[this.filterTarget, "filter"], [this.sortTarget, "sort"], [this.colorTarget, "color"]]) {
          target.value = state.dataset[key] || ""
          target.disabled = !target.value
        }
      }
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() { clearTimeout(this.timer) }
}
