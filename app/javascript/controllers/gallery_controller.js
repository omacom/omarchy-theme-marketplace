import { Controller } from "@hotwired/stimulus"

// Pagination links promote the frame navigation to a Turbo visit (so the URL updates), and Turbo
// scrolls visits to the top of the page. After the new page renders, bring the gallery back into
// view. Filters and search inside the frame are left alone: they are already near its top.
export default class extends Controller {
  paginate() {
    this.pending = true
  }

  loaded() {
    if (!this.pending) return
    this.pending = false
    requestAnimationFrame(() => this.element.scrollIntoView({ block: "start" }))
  }
}
