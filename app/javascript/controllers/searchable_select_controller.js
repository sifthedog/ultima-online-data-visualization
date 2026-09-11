import { Controller } from "@hotwired/stimulus"

// Progressively enhances a <select> into a searchable combobox: it stays hidden as the real
// form field while an input filters a server-rendered list and syncs picks back to it.
export default class extends Controller {
  static targets = [ "select", "input", "list", "option" ]

  connect() {
    this.activeOption = null
    this.selectTarget.hidden = true
    this.inputTarget.hidden = false
    this.close()
  }

  open() {
    this.listTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.listTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.value = this.currentLabel()
    this.setActive(null)
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    this.optionTargets.forEach((option) => {
      option.hidden = !option.textContent.trim().toLowerCase().includes(query)
    })

    this.setActive(this.visibleOptions()[0] || null)
    this.open()
  }

  pick(event) {
    this.select(event.currentTarget)
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.open()
        this.moveActive(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.moveActive(-1)
        break
      case "Enter":
        if (this.activeOption) {
          event.preventDefault()
          this.select(this.activeOption)
        }
        break
      case "Escape":
        this.close()
        break
    }
  }

  select(option) {
    this.selectTarget.value = option.dataset.value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  currentLabel() {
    const selected = this.selectTarget.options[this.selectTarget.selectedIndex]
    return selected && selected.value ? selected.text : ""
  }

  visibleOptions() {
    return this.optionTargets.filter((option) => !option.hidden)
  }

  moveActive(step) {
    const options = this.visibleOptions()
    if (options.length === 0) return

    const currentIndex = options.indexOf(this.activeOption)
    const nextIndex = (currentIndex + step + options.length) % options.length
    this.setActive(options[nextIndex])
  }

  setActive(option) {
    if (this.activeOption) this.activeOption.classList.remove("bg-slate-800")
    this.activeOption = option
    if (this.activeOption) this.activeOption.classList.add("bg-slate-800")
  }
}
