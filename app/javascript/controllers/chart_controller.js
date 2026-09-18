import { Controller } from "@hotwired/stimulus"

const NUMBER = new Intl.NumberFormat("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 })

// Replaces the SVG <title> tooltips (which the browser only shows after its own delay) with an
// instant styled one, and lets a drag across bars pin a summary of the whole selected span.
export default class extends Controller {
  static targets = [ "band", "tooltip", "selection" ]

  connect() {
    this.anchor = null
    this.selected = null

    this.bandTargets.forEach((band) => {
      const title = band.querySelector("title")
      if (!title) return

      band.setAttribute("aria-label", title.textContent)
      title.remove()
    })
  }

  start(event) {
    const band = this.bandAt(event)
    if (!band) return

    this.clear()
    this.anchor = band
    event.currentTarget.setPointerCapture(event.pointerId)
    this.track(event)
  }

  track(event) {
    const band = this.bandAt(event)
    if (this.anchor) this.paint(this.anchor, band || this.anchor)

    // A pinned selection outranks whatever bar the pointer happens to be over.
    const text = this.selected ? this.summarize(...this.selected) : band?.dataset.summary
    if (text) this.show(text, event)
    else this.tooltipTarget.hidden = true
  }

  finish(event) {
    const band = this.bandAt(event)
    if (band === this.anchor) this.clear()

    this.anchor = null
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
  }

  hide() {
    if (!this.anchor) this.tooltipTarget.hidden = true
  }

  clear() {
    this.selected = null
    this.selectionTarget.setAttribute("width", 0)
    this.tooltipTarget.hidden = true
  }

  bandAt(event) {
    return event.target.closest?.("[data-chart-target='band']") || null
  }

  // Anchor and cursor can be in either order; the selection spans the slots between them inclusive.
  paint(anchor, cursor) {
    const [ first, last ] = [ anchor, cursor ].sort((a, b) => a.dataset.index - b.dataset.index)
    const left = Number(first.dataset.slotX)

    this.selected = [ first, last ]
    this.selectionTarget.setAttribute("x", left)
    this.selectionTarget.setAttribute("width", Number(last.dataset.slotX) + Number(last.dataset.slotW) - left)
  }

  summarize(first, last) {
    const bands = this.bandTargets.slice(Number(first.dataset.index), Number(last.dataset.index) + 1)
    const estimated = bands.filter((band) => band.dataset.attempts !== "").map((band) => Number(band.dataset.attempts))
    const total = estimated.reduce((sum, attempts) => sum + attempts, 0)
    const missing = bands.length - estimated.length

    return [
      `${first.dataset.from}–${last.dataset.to}`,
      estimated.length ? `${NUMBER.format(total)} attempts` : "no estimate for this range",
      estimated.length ? `${NUMBER.format(total / estimated.length)} per point` : null,
      `${bands.length} points${missing ? ` · ${missing} without an estimate` : ""}`
    ].filter(Boolean).join("\n")
  }

  show(text, event) {
    const tooltip = this.tooltipTarget
    const box = tooltip.parentElement.getBoundingClientRect()

    tooltip.textContent = text
    tooltip.hidden = false

    const x = event.clientX - box.left
    const y = event.clientY - box.top
    tooltip.style.left = `${Math.max(0, Math.min(x + 12, box.width - tooltip.offsetWidth))}px`
    tooltip.style.top = `${y + tooltip.offsetHeight + 16 > box.height ? y - tooltip.offsetHeight - 8 : y + 16}px`
  }
}
