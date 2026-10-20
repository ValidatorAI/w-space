import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "panel", "results"]

  connect() {
    this._abortController = null
    this._requestId = 0
    this._debounceTimer = null
    this._boundKeydown = this.handleGlobalKeydown.bind(this)
    this._boundInput = this.handleInput.bind(this)
    this._boundFocus = this.handleFocus.bind(this)
    this._boundAskButtonClick = this.handleAskButtonClick.bind(this)
    this.inputTarget.addEventListener("input", this._boundInput)
    this.inputTarget.addEventListener("focus", this._boundFocus)
    this.element.addEventListener("click", this._boundAskButtonClick)
    document.addEventListener("keydown", this._boundKeydown)
  }

  disconnect() {
    this.cancelPendingRequest()
    this.inputTarget?.removeEventListener("input", this._boundInput)
    this.inputTarget?.removeEventListener("focus", this._boundFocus)
    this.element.removeEventListener("click", this._boundAskButtonClick)
    document.removeEventListener("keydown", this._boundKeydown)
  }

  handleFocus() {
    const query = this.inputTarget.value.trim()

    if (query.length > 3) {
      this.openSearch()
      return
    }

    this.closeSearch()
  }

  handleInput(event) {
    const query = event.target.value.trim()

    if (!query) {
      this.cancelPendingRequest()
      this.closeSearch()
      return
    }

    if (query.length < 4) {
      this.cancelPendingRequest()
      this.closeSearch()
      return
    }

    this.openSearch()
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this.fetchResults(query), 250)
  }

  handleGlobalKeydown(event) {
    const isMetaKey = event.metaKey || event.ctrlKey
    const isK = event.key === "k" || event.key === "K"

    if (isMetaKey && isK) {
      event.preventDefault()
      this.toggleSearch()
    }
  }

  toggleSearch() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.openSearch()
      this.inputTarget.focus()
      return
    }

    this.closeSearch()
  }

  openSearch() {
    this.panelTarget.classList.remove("hidden")
  }

  close() {
    this.closeSearch()
  }

  closeSearch() {
    this.panelTarget.classList.add("hidden")
    this.cancelPendingRequest()
    this.renderDefaultState()
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeSearch()
    }
  }

  fetchResults(query) {
    this.cancelPendingRequest()
    this.renderLoading()

    const requestId = ++this._requestId
    const controller = new AbortController()
    this._abortController = controller

    fetch(`/searches.json?q=${encodeURIComponent(query)}`, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest"
      },
      signal: controller.signal
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Search failed: ${response.status}`)
        }
        return response.json()
      })
      .then((payload) => {
        if (requestId !== this._requestId) {
          return
        }

        const items = Array.isArray(payload.results) ? payload.results : []
        this.renderResults(items, query)
      })
      .catch((error) => {
        if (error.name === "AbortError") {
          return
        }

        console.error("Search request failed", error)
        this.renderHint("Search unavailable right now")
      })
  }

  cancelPendingRequest() {
    if (this._abortController) {
      this._abortController.abort()
      this._abortController = null
    }

    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer)
      this._debounceTimer = null
    }
  }

  renderDefaultState() {
    if (this.resultsTarget) {
      this.resultsTarget.innerHTML = ""
    }
  }

  renderHint(message) {
    if (!this.resultsTarget) return

    this.resultsTarget.innerHTML = `
      <div class="room-shell-topbar__search-empty">
        <span>${this.escapeHtml(message)}</span>
      </div>
    `
  }

  renderLoading() {
    if (!this.resultsTarget) return

    this.resultsTarget.innerHTML = `
      <div class="room-shell-topbar__search-loading" aria-live="polite">
        <span class="room-shell-topbar__search-spinner" aria-hidden="true"></span>
        <span>Loading…</span>
      </div>
    `
  }

  renderResults(items, query) {
    if (!this.resultsTarget) return

    const askCard = `
      <button type="button" class="room-shell-topbar__search-ask-card" data-action="click->search-dropdown#askFromW" data-query="${this.escapeHtml(query || "")}">
        <span class="room-shell-topbar__search-ask-icon" aria-hidden="true">W</span>
        <span class="room-shell-topbar__search-ask-copy">
          <span class="room-shell-topbar__search-ask-title">Ask PWR about workspace context</span>
          <span class="room-shell-topbar__search-ask-subtitle">Could not find the answer above? Ask W to synthesize an answer from all workspace context.</span>
        </span>
        <span class="room-shell-topbar__search-ask-arrow" aria-hidden="true">→</span>
      </button>
    `

    const searchMoreLink = query
      ? `<a href="/searches?q=${encodeURIComponent(query)}" class="room-shell-topbar__search-more-link" data-action="click->search-dropdown#closeSearch">Search more</a>`
      : ""

    if (!items.length) {
      this.resultsTarget.innerHTML = `
        <div class="room-shell-topbar__search-empty">
          <span>No results for “${this.escapeHtml(query)}”</span>
        </div>
        ${searchMoreLink}
        ${askCard}
      `
      return
    }

    this.resultsTarget.innerHTML = items
      .slice(0, 5)
      .map((item) => {
        const title = this.truncateText(item.title || "Result", 40)
        const snippet = this.truncateText(item.snippet || "", 100)
        const project = item.project_name ? `<span class="room-shell-topbar__search-project">${this.escapeHtml(item.project_name)}</span>` : ""
        const typeKey = item.type || "message"
        const typeClass = this.typeBadgeClass(typeKey)
        const typeLabel = this.typeBadgeLabel(typeKey)
        const type = item.type ? `<span class="room-shell-topbar__search-type ${typeClass}">${this.escapeHtml(typeLabel)}</span>` : ""
        const date = item.created_at ? `<span class="room-shell-topbar__search-date">${this.escapeHtml(this.formatDate(item.created_at))}</span>` : ""

        return `
          <a href="${this.escapeHtml(item.url || "#")}" class="room-shell-topbar__search-result" data-action="click->search-dropdown#closeSearch">
            <div class="room-shell-topbar__search-result-header">
              ${type}
              <span class="room-shell-topbar__search-result-title">${this.escapeHtml(title)}</span>
              <span class="room-shell-topbar__search-meta-block">
                ${project}
                ${date}
              </span>
            </div>
            <div class="room-shell-topbar__search-result-snippet">${this.escapeHtml(snippet)}</div>
          </a>
        `
      })
      .join("") + searchMoreLink + askCard
  }

  handleAskButtonClick(event) {
    const askButton = event.target.closest(".room-shell-topbar__ask-button")
    if (!askButton) {
      return
    }

    event.preventDefault()
    event.stopPropagation()

    const query = (this.inputTarget?.value || "").trim()
    if (!query) {
      return
    }

    this.closeSearch()
    this.postAskToBot(query)
  }

  askFromW(event) {
    event.preventDefault()
    event.stopPropagation()

    const query = (event.currentTarget.dataset.query || this.inputTarget?.value || "").trim()
    if (!query) {
      return
    }

    this.closeSearch()
    this.postAskToBot(query)
  }

  postAskToBot(query) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    const params = new URLSearchParams({ q: query })

    fetch("/searches/ask", {
      method: "POST",
      headers: {
        Accept: "text/html,application/xhtml+xml",
        "X-CSRF-Token": csrfToken || "",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"
      },
      body: params.toString(),
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.redirected && response.url) {
          window.location.href = response.url
          return
        }

        if (response.redirected && response.url) {
          window.location.href = response.url
        }
      })
      .catch((error) => {
        console.error("Ask W failed", error)
      })
  }

  typeBadgeClass(type) {
    const map = {
      room: "type-room",
      message: "type-message",
      project: "type-project",
      decision: "type-decision",
      all_hands_decision: "type-decision",
      adr: "type-adr",
      knowledge: "type-knowledge",
      knowledge_activity: "type-knowledge",
      todo: "type-todo",
      task: "type-task",
      milestone: "type-milestone",
      all_hands_action_item: "type-task",
      directory_item: "type-directory",
      external_asset: "type-asset",
      attention_item: "type-attention",
      all_hands_takeaway: "type-note",
      note: "type-note",
      bottleneck: "type-bottleneck",
      artifact: "type-artifact"
    }

    return map[type] || "type-message"
  }

  typeBadgeLabel(type) {
    const map = {
      room: "ROOM",
      message: "MESSAGE",
      project: "PROJECT",
      decision: "DECISION",
      all_hands_decision: "DECISION",
      adr: "ADR",
      knowledge: "KNOWLEDGE",
      knowledge_activity: "KNOWLEDGE",
      todo: "TODO",
      task: "TASK",
      milestone: "MILESTONE",
      all_hands_action_item: "TASK",
      directory_item: "FILE",
      external_asset: "ASSET",
      attention_item: "ATTENTION",
      all_hands_takeaway: "NOTE",
      note: "NOTE",
      bottleneck: "BOTTLENECK",
      artifact: "ARTIFACT"
    }

    return map[type] || "RESULT"
  }

  formatDate(value) {
    if (!value) return ""

    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return ""

    return date.toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric"
    })
  }

  truncateText(value, maxLength = 100) {
    const clean = String(value ?? "").replace(/\s+/g, " ").trim()
    if (!clean) return ""
    if (clean.length <= maxLength) return clean
    return `${clean.slice(0, Math.max(0, maxLength - 1)).trim()}…`
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}
