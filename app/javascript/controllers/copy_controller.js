import { Controller } from "@hotwired/stimulus"

// Copies data-copy-text-value to the clipboard and briefly swaps the icon/label to "Copied".
export default class extends Controller {
  static targets = ["idle", "done"]
  static values = { text: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      const ta = document.createElement("textarea")
      ta.value = this.textValue
      document.body.appendChild(ta)
      ta.select()
      document.execCommand("copy")
      ta.remove()
    }
    this.flash()
  }

  flash() {
    if (!this.hasIdleTarget) return
    this.idleTarget.hidden = true
    this.doneTarget.hidden = false
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.idleTarget.hidden = false; this.doneTarget.hidden = true }, 1500)
  }
}
