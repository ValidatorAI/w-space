import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "panel", "results"]

  connect() {
    this._abortController = null
    this._requestId = 0
    this._debounceTimer = null
    this._boundKeydown = this.handleGlobalKeydown.bind(this)
    this._boundInput = this.handleInput.bind(this)
    this._boundFocus = this.openSearch.bind(this)
    this.inputTarget.addEventListener("input", this._boundInput)
    this.inputTarget.addEventListener("focus", this._boundFocus)
    document.addEventListener("keydown", this._boundKeydown)
  }

  disconnect() {
    this.cancelPendingRequest()
    this.inputTarget?.removeEventListener("input", this._boundInput)
    this.inputTarget?.removeEventListener("focus", this._boundFocus)
    document.removeEventListener("keydown", this._boundKeydown)
  }

  handleInput(event) {
    const query = event.target.value.trim()

    this.openSearch()

    if (!query) {
      this.cancelPendingRequest()
      this.renderDefaultState()
      return
    }

    if (query.length < 4) {
      this.cancelPendingRequest()
      this.renderHint("Type at least 4 characters to search")
      return
    }

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

    if (!items.length) {
      this.resultsTarget.innerHTML = `
        <div class="room-shell-topbar__search-empty">
          <span>No results for “${this.escapeHtml(query)}”</span>
        </div>
      `
      return
    }

    this.resultsTarget.innerHTML = items
      .slice(0, 5)
      .map((item) => {
        const project = item.project_name ? `<span class="room-shell-topbar__search-project">${this.escapeHtml(item.project_name)}</span>` : ""
        const type = item.type ? `<span class="room-shell-topbar__search-type">${this.escapeHtml(item.type)}</span>` : ""

        return `
          <a href="${this.escapeHtml(item.url || "#")}" class="room-shell-topbar__search-result" data-action="click->search-dropdown#closeSearch">
            <div class="room-shell-topbar__search-result-header">
              ${type}
              <span class="room-shell-topbar__search-result-title">${this.escapeHtml(item.title || "Result")}</span>
              ${project}
            </div>
            <div class="room-shell-topbar__search-result-snippet">${this.escapeHtml(item.snippet || "")}</div>
          </a>
        `
      })
      .join("") + `
        <div class="room-shell-topbar__search-ask">
          <a href="/searches?q=${encodeURIComponent(query)}" class="room-shell-topbar__search-ask-link">Ask from W</a>
        </div>
      `
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
