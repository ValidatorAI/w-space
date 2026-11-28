import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "stepOne", "stepTwo" ]

  connect() {
    if (!this.hasStepOneTarget) {
      const step1 = this.element.querySelector("[data-step='1']")
      if (step1) step1.dataset.firstRunTarget = "stepOne"
    }
    if (!this.hasStepTwoTarget) {
      const step2 = this.element.querySelector("[data-step='2']")
      if (step2) step2.dataset.firstRunTarget = "stepTwo"
    }
  }

  next(event) {
    if (event) event.preventDefault()

    const stepOne = this.hasStepOneTarget ? this.stepOneTarget : this.element.querySelector("[data-step='1']")
    const firstInvalid = stepOne?.querySelector("input[required]:invalid")
    if (firstInvalid) {
      firstInvalid.reportValidity()
      return
    }

    this.showStep("2")
  }

  back(event) {
    if (event) event.preventDefault()
    this.showStep("1")
  }

  showStep(step) {
    const isFirst = step === "1"
    const stepOne = this.hasStepOneTarget ? this.stepOneTarget : this.element.querySelector("[data-step='1']")
    const stepTwo = this.hasStepTwoTarget ? this.stepTwoTarget : this.element.querySelector("[data-step='2']")

    if (stepOne) stepOne.hidden = !isFirst
    if (stepTwo) stepTwo.hidden = isFirst
  }
}
