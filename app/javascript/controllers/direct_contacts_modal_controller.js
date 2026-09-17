import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "search", "section", "contact", "empty" ]

  connect() {
    this.filter()
  }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    this.searchTarget.focus()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()

    this.contactTargets.forEach((contact) => {
      contact.hidden = !contact.dataset.directContactsModalSearchValue.includes(query)
    })

    this.sectionTargets.forEach((section) => {
      section.hidden = !this.contactTargets.some((contact) => section.contains(contact) && !contact.hidden)
    })

    this.emptyTarget.hidden = this.contactTargets.some((contact) => !contact.hidden)
  }

  reset() {
    this.searchTarget.value = ""
    this.filter()
  }
}