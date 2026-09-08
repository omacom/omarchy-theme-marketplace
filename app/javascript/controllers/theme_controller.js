import { Controller } from "@hotwired/stimulus"

// Light/dark toggle (replaces mode-watcher). State lives in localStorage["theme"] and the
// `dark` class on <html>; the inline script in the layout applies it before first paint.
export default class extends Controller {
  toggle() {
    const next = document.documentElement.classList.contains("dark") ? "light" : "dark"
    document.documentElement.classList.toggle("dark", next === "dark")
    document.documentElement.style.colorScheme = next
    try { localStorage.setItem("theme", next) } catch {}
    this.element.setAttribute("aria-label", next === "dark" ? "Switch to light theme" : "Switch to dark theme")
  }
}
