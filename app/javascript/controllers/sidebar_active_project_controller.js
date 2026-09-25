import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  connect() {
    this.handleNavigation = this.handleNavigation.bind(this)

    document.addEventListener("turbo:load", this.handleNavigation)
    document.addEventListener("turbo:render", this.handleNavigation)

    this.handleNavigation()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleNavigation)
    document.removeEventListener("turbo:render", this.handleNavigation)
  }

  async handleNavigation() {
    const activeProjectItem = this.activeProjectItem

    if (!activeProjectItem) return

    await nextFrame()
    activeProjectItem.scrollIntoView({ behavior: "smooth", block: "center", inline: "nearest" })
  }

  get activeProjectItem() {
    const projectIdFromPath = this.projectIdFromPath

    if (projectIdFromPath) {
      const projectItem = this.element.querySelector(`[data-project-id="${projectIdFromPath}"]`)

      if (projectItem) return projectItem
    }

    const currentRoomId = window.Current?.room?.id

    if (currentRoomId) {
      const roomLink = this.element.querySelector(`[data-room-id="${currentRoomId}"]`)

      if (roomLink) return roomLink.closest(".sidebar-projects__item")
    }

    return null
  }

  get projectIdFromPath() {
    const match = window.location.pathname.match(/\/company\/projects\/(\d+)(?:\/|$)/)

    if (match) return Number(match[1])

    return null
  }
}
