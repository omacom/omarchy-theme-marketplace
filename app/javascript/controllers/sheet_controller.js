import { Controller } from "@hotwired/stimulus"

// Port of the shadcn Sheet used for the mobile menu: overlay + right-side panel with the
// same data-state driven enter/exit animations.
export default class extends Controller {
  static targets = ["overlay", "panel", "trigger"]

  connect() { this.onKeydown = (e) => { if (e.key === "Escape") this.close() } }

  open() {
    this.overlayTarget.hidden = false
    this.panelTarget.hidden = false
    this.overlayTarget.dataset.state = "open"
    this.panelTarget.dataset.state = "open"
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("keydown", this.onKeydown)
    this.panelTarget.querySelector("a, button")?.focus()
  }

  close() {
    if (this.panelTarget.hidden) return
    this.overlayTarget.dataset.state = "closed"
    this.panelTarget.dataset.state = "closed"
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("keydown", this.onKeydown)
    const done = () => { this.overlayTarget.hidden = true; this.panelTarget.hidden = true }
    this.panelTarget.addEventListener("animationend", done, { once: true })
    setTimeout(done, 250)
  }
}
