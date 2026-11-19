import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle", "panel" ]

  toggleProject() {
    if (!this.hasPanelTarget) return

    const expanded = !this.panelTarget.hidden
    this.panelTarget.hidden = expanded
    this.toggleTarget.textContent = expanded ? "Collapse" : "Expand"
    this.toggleTarget.setAttribute("aria-expanded", String(!expanded))
  }

  toggleNode(event) {
    const button = event.currentTarget
    const node = button.closest(".debug-topic-node")
    const children = node?.querySelector(":scope > .debug-topic-children")

    if (!children) return

    const expanded = button.getAttribute("aria-expanded") === "true"
    children.hidden = expanded
    button.textContent = expanded ? "+" : "−"
    button.setAttribute("aria-expanded", String(!expanded))
  }
}
