import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "cancel" ]

  submit() {
    const form = this.element?.form ?? this.element

    if (!form) return

    if (form.requestSubmit) {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }

  cancel() {
    this.cancelTarget?.click()
  }

  preventAttachment(event) {
    event.preventDefault()
  }
}
