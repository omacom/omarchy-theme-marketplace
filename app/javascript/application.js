// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Gallery filters and pagination are frame navigations promoted to visits (so the URL updates).
// Turbo 8 neither remembers a scroll position for those history entries nor scrolls to the top on
// the next page visit, so opening a theme from a lower card landed mid-page and Back lost its
// place. Remember positions per URL ourselves; reset after a page render on forward visits, restore
// on Back/Forward. Promoted frame visits fire turbo:load without turbo:render, so they are left alone.
const scrollPositions = new Map()
let visitAction
let pageRendered = false
document.addEventListener("turbo:before-visit", () => scrollPositions.set(location.href, window.scrollY))
document.addEventListener("turbo:visit", (event) => { visitAction = event.detail.action })
document.addEventListener("turbo:render", () => { pageRendered = true })
document.addEventListener("turbo:load", () => {
  if (pageRendered && visitAction === "restore") {
    const y = scrollPositions.get(location.href)
    if (y !== undefined) window.scrollTo(0, y)
  } else if (pageRendered && !location.hash) {
    window.scrollTo(0, 0)
  }
  pageRendered = false
  visitAction = undefined
})
