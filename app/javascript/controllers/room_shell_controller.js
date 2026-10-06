import { Controller } from "@hotwired/stimulus"

const MOBILE_QUERY = "(max-width: 72ch)"
const CONTEXT_COLLAPSE_QUERY = "(max-width: 110ch)"

export default class extends Controller {
  static targets = [ "tab", "panel", "context", "contextToggle", "workspace", "workspaceToggle" ]
  static values = { defaultTab: String }

  connect() {
    this.mobileMedia = window.matchMedia(MOBILE_QUERY)
    this.contextMedia = window.matchMedia(CONTEXT_COLLAPSE_QUERY)
    this.handleViewportChange = this.handleViewportChange.bind(this)
    this.markActiveSidebarLink = this.markActiveSidebarLink.bind(this)

    this.mobileMedia.addEventListener("change", this.handleViewportChange)
    this.contextMedia.addEventListener("change", this.handleViewportChange)
    this.workspaceTarget?.addEventListener("turbo:frame-load", this.markActiveSidebarLink)
    this.workspaceTarget?.addEventListener("click", this.handleSidebarRoomClick)
    document.addEventListener("turbo:render", this.markActiveSidebarLink)
    document.addEventListener("turbo:load", this.markActiveSidebarLink)

    this.selectByName(this.defaultTabValue || "conversation")
    this.handleViewportChange()
    this.markActiveSidebarLink()
  }

  disconnect() {
    this.mobileMedia?.removeEventListener("change", this.handleViewportChange)
    this.contextMedia?.removeEventListener("change", this.handleViewportChange)
    this.workspaceTarget?.removeEventListener("turbo:frame-load", this.markActiveSidebarLink)
    this.workspaceTarget?.removeEventListener("click", this.handleSidebarRoomClick)
    document.removeEventListener("turbo:render", this.markActiveSidebarLink)
    document.removeEventListener("turbo:load", this.markActiveSidebarLink)
  }

  switchTab(event) {
    this.selectByName(event.params.tab)
  }

  toggleContext() {
    this.element.classList.toggle("workspace-room--context-hidden")
    this.syncContextToggleButton()
  }

  toggleWorkspace() {
    if (!this.hasWorkspaceTarget) return

    const open = this.workspaceTarget.classList.toggle("workspace-room__workspace--open")
    if (this.hasWorkspaceToggleTarget) {
      this.workspaceToggleTarget.setAttribute("aria-expanded", String(open))
    }
  }

  closeWorkspaceIfOpen(event) {
    if (!this.mobileMedia?.matches || !this.hasWorkspaceTarget) return
    if (!this.workspaceTarget.classList.contains("workspace-room__workspace--open")) return

    if (this.workspaceTarget.contains(event.target)) return
    if (this.hasWorkspaceToggleTarget && this.workspaceToggleTarget.contains(event.target)) return

    this.workspaceTarget.classList.remove("workspace-room__workspace--open")
    if (this.hasWorkspaceToggleTarget) {
      this.workspaceToggleTarget.setAttribute("aria-expanded", "false")
    }
  }

  handleViewportChange() {
    if (this.contextMedia?.matches) {
      this.element.classList.add("workspace-room--context-hidden")
    } else {
      this.element.classList.remove("workspace-room--context-hidden")
    }

    if (!this.mobileMedia?.matches && this.hasWorkspaceTarget) {
      this.workspaceTarget.classList.remove("workspace-room__workspace--open")
      if (this.hasWorkspaceToggleTarget) {
        this.workspaceToggleTarget.setAttribute("aria-expanded", "false")
      }
    }

    this.syncContextToggleButton()
  }

  selectByName(name) {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.roomShellTabParam === name
      tab.classList.toggle("active", active)
      tab.setAttribute("aria-selected", String(active))
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.roomShellPanel === name
      panel.hidden = !active
      panel.classList.toggle("active", active)
    })
  }

  syncContextToggleButton() {
    if (!this.hasContextToggleTarget) return

    const expanded = !this.element.classList.contains("workspace-room--context-hidden")
    this.contextToggleTarget.setAttribute("aria-expanded", String(expanded))
  }

  handleSidebarRoomClick(event) {
    const link = event.target.closest("a.room")
    if (!link) return

    requestAnimationFrame(() => this.markActiveSidebarLink())
  }

  markActiveSidebarLink() {
    if (!this.hasWorkspaceTarget) return

    const roomLinks = Array.from(this.workspaceTarget.querySelectorAll("a.room"))
    roomLinks.forEach((link) => link.classList.remove("workspace-room__active"))

    const currentPath = window.location.pathname
    const activeByPath = roomLinks.find((link) => {
      try {
        return new URL(link.href).pathname === currentPath
      } catch {
        return false
      }
    })

    if (activeByPath) {
      activeByPath.classList.add("workspace-room__active")
      return
    }

    const isRoomPath = /\/rooms\//.test(currentPath)
    if (!isRoomPath) return

    const roomId = window.Current?.room?.id
    if (!roomId) return

    const activeRoomLink = this.workspaceTarget.querySelector(`[data-room-id="${roomId}"]`)
    activeRoomLink?.classList.add("workspace-room__active")
  }
}
