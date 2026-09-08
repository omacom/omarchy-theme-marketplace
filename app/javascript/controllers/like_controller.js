import { Controller } from "@hotwired/stimulus"

// Local-only like toggle (persistence arrives with the API in a later phase).
export default class extends Controller {
  static targets = ["count", "outline", "fill"]
  static values = { count: Number, liked: Boolean }

  toggle(event) {
    event.preventDefault()
    this.likedValue = !this.likedValue
  }

  likedValueChanged() {
    const liked = this.likedValue
    this.element.setAttribute("aria-pressed", liked)
    this.element.setAttribute("aria-label", liked ? "Unlike this theme" : "Like this theme")
    this.element.classList.toggle("text-primary", liked)
    // <svg> has no .hidden property; toggle the attribute instead
    this.outlineTarget.toggleAttribute("hidden", liked)
    this.fillTarget.toggleAttribute("hidden", !liked)
    this.countTarget.textContent = this.countValue + (liked ? 1 : 0)
  }
}
