import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.selectByName("project-topic")
  }

  switchTab(event) {
    const tabName = event.params.tab
    this.selectByName(tabName)
  }

  selectByName(name) {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.debugTabsTabParam === name
      tab.classList.toggle("active", active)
      tab.setAttribute("aria-selected", String(active))
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.debugTabsPanel === name
      panel.hidden = !active
      panel.classList.toggle("active", active)
    })
  }
}
