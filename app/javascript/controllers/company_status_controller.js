import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    periods: Object,
    selectedPeriod: String
  }

  static targets = [
    "content",
    "priorities",
    "progress",
    "risks",
    "dependencies",
    "changes",
    "decisions",
    "learnings",
    "overlay",
    "drawer",
    "drawerCategory",
    "drawerTitle",
    "drawerDescription",
    "drawerImpact",
    "drawerMeta",
    "drawerActions"
  ]

  connect() {
    const serverData = this.hasPeriodsValue ? this.periodsValue : {}
    this.statusData = serverData || {}

    this.handleMonthChange = this.handleMonthChange.bind(this)
    this.handleContentClick = this.handleContentClick.bind(this)

    this.monthSelector = document.getElementById("company-month-selector")
    const initialMonth = this.hasSelectedPeriodValue ? this.selectedPeriodValue : Object.keys(this.statusData)[0] || ""

    if (this.monthSelector) {
      this.monthSelector.addEventListener("change", this.handleMonthChange)
      this.currentMonth = this.monthSelector.value || initialMonth
    } else {
      this.currentMonth = initialMonth
    }

    this.renderCompanyStatus(this.currentMonth)

    if (this.hasContentTarget) {
      this.contentTarget.addEventListener("click", this.handleContentClick)
    }
  }

  disconnect() {
    if (this.monthSelector) {
      this.monthSelector.removeEventListener("change", this.handleMonthChange)
    }
    if (this.hasContentTarget) {
      this.contentTarget.removeEventListener("click", this.handleContentClick)
    }
  }

  handleMonthChange(event) {
    const monthId = event?.target?.value || this.currentMonth || this.selectedPeriodValue || ""
    this.changeMonth(monthId)
  }

  changeMonth(monthId) {
    if (!monthId) return

    this.currentMonth = monthId

    if (this.monthSelector && this.monthSelector.value !== monthId) {
      this.monthSelector.value = monthId
    }

    this.closeDrawer()
    this.updateUrlParam(monthId)
    this.renderCompanyStatus(monthId)
  }

  updateUrlParam(monthId) {
    if (window.history && window.history.replaceState) {
      const url = new URL(window.location)
      url.searchParams.set("period", monthId)
      window.history.replaceState({}, "", url)
    }
  }

  renderCompanyStatus(monthId) {
    const data = this.statusData ? this.statusData[monthId] : null
    if (!data) {
      this.renderEmptyState()
      return
    }

    if (this.hasContentTarget) {
      this.contentTarget.style.opacity = "0.4"
    }

    setTimeout(() => {
      if (this.hasPrioritiesTarget) {
        this.prioritiesTarget.innerHTML = (data.priorities || []).map((priority) => `
          <div class="company-priority-item company-clickable" data-month-id="${monthId}" data-collection-key="priorities" data-item-id="${priority.id}">
            <span class="company-priority-title">${priority.title}</span>
            <span class="company-priority-outcome">Outcome: ${priority.outcome}</span>
          </div>
        `).join("") || '<span class="company-empty-note">No priorities recorded.</span>'
      }

      if (this.hasProgressTarget) {
        this.progressTarget.innerHTML = (data.progress && data.progress.length > 0)
          ? data.progress.map((progress) => `
            <div class="company-progress-row company-clickable" data-month-id="${monthId}" data-collection-key="progress" data-item-id="${progress.id}">
              <div class="company-progress-labels">
                <span>${progress.label}</span>
                <span>${progress.percent}%</span>
              </div>
              <div class="company-progress-bar-bg">
                <div class="company-progress-bar-fill" style="width: ${progress.percent}%; background: ${progress.color};"></div>
              </div>
              <span class="company-evidence-note">Evidence: ${progress.evidence}</span>
            </div>
          `).join("")
          : '<span class="company-empty-note">No items recorded.</span>'
      }

      if (this.hasRisksTarget) {
        this.risksTarget.innerHTML = (data.risks && data.risks.length > 0)
          ? data.risks.map((risk) => `
            <div class="company-risk-item ${risk.type} company-clickable" data-month-id="${monthId}" data-collection-key="risks" data-item-id="${risk.id}">
              <div class="company-risk-icon">${risk.icon}</div>
              <div class="company-risk-text">
                <span class="company-risk-title">${risk.title}</span>
                <span class="company-risk-desc">${risk.desc}</span>
              </div>
            </div>
          `).join("")
          : '<span class="company-empty-note">No immediate risks logged for this period.</span>'
      }

      if (this.hasDependenciesTarget) {
        this.dependenciesTarget.innerHTML = (data.dependencies && data.dependencies.length > 0)
          ? data.dependencies.map((dependency) => `
            <div class="company-dependency-row company-clickable" data-month-id="${monthId}" data-collection-key="dependencies" data-item-id="${dependency.id}">
              <span class="company-dep-tag">${dependency.from}</span>
              <span class="company-dep-arrow">→</span>
              <span class="company-dep-tag">${dependency.to}</span>
            </div>
          `).join("")
          : '<span class="company-empty-note">No dependencies logged.</span>'
      }

      if (this.hasChangesTarget) {
        this.changesTarget.innerHTML = (data.changes && data.changes.length > 0)
          ? data.changes.map((change) => `
            <li class="company-clickable" data-month-id="${monthId}" data-collection-key="changes" data-item-id="${change.id}">${change.text}</li>
          `).join("")
          : '<span class="company-empty-note">No changes logged.</span>'
      }

      if (this.hasDecisionsTarget) {
        this.decisionsTarget.innerHTML = (data.decisions && data.decisions.length > 0)
          ? data.decisions.map((decision) => {
              const roomLabel = decision?.details?.room_label
              const displayText = decision?.label || decision?.text || decision?.title || "Decision"
              return `
                <li class="company-clickable" data-month-id="${monthId}" data-collection-key="decisions" data-item-id="${decision.id}">
                  <span>${displayText}</span>
                  ${roomLabel ? `<span class="company-room-badge">${roomLabel}</span>` : ""}
                </li>
              `
            }).join("")
          : '<span class="company-empty-note">No decisions logged.</span>'
      }

      if (this.hasLearningsTarget) {
        this.learningsTarget.innerHTML = (data.learnings && data.learnings.length > 0)
          ? data.learnings.map((learning) => `
            <li class="company-clickable" data-month-id="${monthId}" data-collection-key="learnings" data-item-id="${learning.id}">${learning.text}</li>
          `).join("")
          : '<span class="company-empty-note">No learnings logged.</span>'
      }

      if (this.hasContentTarget) {
        this.contentTarget.style.opacity = "1"
      }
    }, 120)
  }

  renderEmptyState() {
    const emptyStateMap = {
      priorities: '<span class="company-empty-note">No priorities recorded.</span>',
      progress: '<span class="company-empty-note">No progress recorded.</span>',
      risks: '<span class="company-empty-note">No immediate risks logged for this period.</span>',
      dependencies: '<span class="company-empty-note">No dependencies logged.</span>',
      changes: '<span class="company-empty-note">No changes logged.</span>',
      decisions: '<span class="company-empty-note">No decisions logged.</span>',
      learnings: '<span class="company-empty-note">No learnings logged.</span>'
    }

    if (this.hasPrioritiesTarget) this.prioritiesTarget.innerHTML = emptyStateMap.priorities
    if (this.hasProgressTarget) this.progressTarget.innerHTML = emptyStateMap.progress
    if (this.hasRisksTarget) this.risksTarget.innerHTML = emptyStateMap.risks
    if (this.hasDependenciesTarget) this.dependenciesTarget.innerHTML = emptyStateMap.dependencies
    if (this.hasChangesTarget) this.changesTarget.innerHTML = emptyStateMap.changes
    if (this.hasDecisionsTarget) this.decisionsTarget.innerHTML = emptyStateMap.decisions
    if (this.hasLearningsTarget) this.learningsTarget.innerHTML = emptyStateMap.learnings

    if (this.hasContentTarget) {
      this.contentTarget.style.opacity = "1"
    }
  }

  handleContentClick(event) {
    const clickable = event.target.closest(".company-clickable")
    if (!clickable) return

    const monthId = clickable.getAttribute("data-month-id") || this.currentMonth
    const collectionKey = clickable.getAttribute("data-collection-key")
    const itemId = clickable.getAttribute("data-item-id")

    if (monthId && collectionKey && itemId) {
      this.openDrawer(monthId, collectionKey, itemId)
    }
  }

  openDrawer(monthId, collectionKey, itemId) {
    const monthData = this.statusData ? this.statusData[monthId] : null
    if (!monthData || !monthData[collectionKey]) return

    const item = monthData[collectionKey].find((entry) => entry.id === itemId)
    if (!item || !item.details) return

    const details = item.details
    if (this.hasDrawerCategoryTarget) {
      this.drawerCategoryTarget.textContent = details.category || collectionKey.toUpperCase()
    }

    let displayTitle = "Detail Overview"
    if (item.title) {
      displayTitle = item.title
    } else if (item.label) {
      displayTitle = item.label
    } else if (item.from && item.to) {
      displayTitle = `${item.from} → ${item.to}`
    } else if (item.text) {
      const tempDiv = document.createElement("div")
      tempDiv.innerHTML = item.text
      const plainText = tempDiv.textContent || tempDiv.innerText || ""
      if (plainText.includes(":")) {
        displayTitle = plainText.split(":")[0]
      } else {
        displayTitle = plainText.length > 40 ? `${plainText.substring(0, 40)}...` : plainText
      }
    }

    if (this.hasDrawerTitleTarget) {
      this.drawerTitleTarget.textContent = displayTitle
    }

    if (this.hasDrawerDescriptionTarget) {
      this.drawerDescriptionTarget.textContent = details.description || ""
    }

    if (this.hasDrawerImpactTarget) {
      this.drawerImpactTarget.textContent = details.impact || ""
    }

    if (this.hasDrawerMetaTarget) {
      const roomLabel = details.room_label ? `<span class="company-meta-pill">🏠 Room: <strong>${details.room_label}</strong></span>` : ""

      this.drawerMetaTarget.innerHTML = `
        ${roomLabel}
        <span class="company-meta-pill">👤 Owner: <strong>${details.owner || "Unassigned"}</strong></span>
        <span class="company-meta-pill">📅 Target: <strong>${details.targetDate || "N/A"}</strong></span>
        <span class="company-meta-pill">📊 Status: <strong>${details.status || "Open"}</strong></span>
      `
    }

    if (this.hasDrawerActionsTarget) {
      this.drawerActionsTarget.innerHTML = (details.actions || []).map((action) => `<li>${action}</li>`).join("")
    }

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("active")
    }
  }

  closeDrawer() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("active")
    }
  }

  closeDrawerOnBackdrop(event) {
    if (event.target === this.overlayTarget) {
      this.closeDrawer()
    }
  }
}
