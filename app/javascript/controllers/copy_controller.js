import { Controller } from "@hotwired/stimulus"

// Copies data-copy-text-value to the clipboard, then shows the "done" targets (and hides the
// "idle" ones) for a moment and announces it. Works on <svg> targets too: use toggleAttribute,
// since `.hidden` is only defined on HTMLElement.
export default class extends Controller {
  static targets = ["idle", "done", "status"]
  static values = { text: String, resetAfter: { type: Number, default: 1500 } }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      const ta = document.createElement("textarea")
      ta.value = this.textValue
      ta.setAttribute("readonly", "")
      ta.style.position = "fixed"
      ta.style.opacity = "0"
      document.body.appendChild(ta)
      ta.select()
      document.execCommand("copy")
      ta.remove()
    }
    this.show(true)
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.show(false), this.resetAfterValue)
  }

  show(done) {
    this.idleTargets.forEach((el) => el.toggleAttribute("hidden", done))
    this.doneTargets.forEach((el) => el.toggleAttribute("hidden", !done))
    this.element.classList.toggle("text-primary", done)
    this.element.setAttribute("data-copied", done)
    if (this.hasStatusTarget) this.statusTarget.textContent = done ? "Copied to clipboard" : ""
  }

  disconnect() { clearTimeout(this.timer) }
}
