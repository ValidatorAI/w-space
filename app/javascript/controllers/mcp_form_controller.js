import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "transport",
    "authentication",
    "httpFields",
    "bearerField",
    "stdioFields",
    "urlInput",
    "authenticationInput",
    "bearerTokenInput",
    "commandInput",
    "argsInput"
  ]

  connect() {
    this.update()
  }

  update() {
    const isHttp = this.transportTarget.value === "http"
    const isStdio = this.transportTarget.value === "stdio"

    this.httpFieldsTarget.hidden = !isHttp
    this.stdioFieldsTarget.hidden = !isStdio

    this.setRequired(this.urlInputTarget, isHttp)
    this.setRequired(this.authenticationInputTarget, isHttp)

    const isBearer = isHttp && this.authenticationTarget.value === "bearer"
    this.bearerFieldTarget.hidden = !isBearer
    this.setRequired(this.bearerTokenInputTarget, isBearer)

    this.setRequired(this.commandInputTarget, isStdio)
    this.setRequired(this.argsInputTarget, isStdio)
  }

  setRequired(input, required) {
    input.required = required

    if (!required) {
      input.setCustomValidity("")
    }
  }
}
