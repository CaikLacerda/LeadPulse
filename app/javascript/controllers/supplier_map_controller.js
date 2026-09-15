import { Controller } from "@hotwired/stimulus"

const LEAFLET_VERSION = "1.9.4"
const LEAFLET_SCRIPT_URL = `https://unpkg.com/leaflet@${LEAFLET_VERSION}/dist/leaflet.js`
const LEAFLET_STYLESHEET_URL = `https://unpkg.com/leaflet@${LEAFLET_VERSION}/dist/leaflet.css`

export default class extends Controller {
  static targets = ["canvas", "placeholder"]

  static values = {
    points: Array,
  }

  connect() {
    this.map = null

    if (!this.pointsValue.length) {
      this.showPlaceholder()
      return
    }

    this.loadLeaflet()
      .then(() => this.renderMap())
      .catch(() => this.showPlaceholder())
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }

  loadLeaflet() {
    if (window.L?.map) return Promise.resolve(window.L)
    if (window.leadPulseLeafletPromise) return window.leadPulseLeafletPromise

    this.ensureLeafletStylesheet()
    window.leadPulseLeafletPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = LEAFLET_SCRIPT_URL
      script.async = true
      script.crossOrigin = "anonymous"
      script.onload = () => window.L?.map ? resolve(window.L) : reject(new Error("Leaflet não foi inicializado."))
      script.onerror = () => {
        window.leadPulseLeafletPromise = null
        reject(new Error("Não foi possível carregar o mapa."))
      }
      document.head.appendChild(script)
    })

    return window.leadPulseLeafletPromise
  }

  ensureLeafletStylesheet() {
    if (document.querySelector(`link[href="${LEAFLET_STYLESHEET_URL}"]`)) return

    const stylesheet = document.createElement("link")
    stylesheet.rel = "stylesheet"
    stylesheet.href = LEAFLET_STYLESHEET_URL
    stylesheet.crossOrigin = "anonymous"
    document.head.appendChild(stylesheet)
  }

  renderMap() {
    if (!this.hasCanvasTarget || !window.L?.map) return

    const leaflet = window.L
    this.map = leaflet.map(this.canvasTarget, {
      center: [-14.235004, -51.92528],
      zoom: 4,
      minZoom: 3,
      maxZoom: 19,
      zoomControl: true,
      attributionControl: true,
      dragging: true,
      scrollWheelZoom: true,
      doubleClickZoom: true,
      boxZoom: true,
      keyboard: true,
      touchZoom: true,
    })

    this.enableInteractions()

    leaflet.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a>',
    }).addTo(this.map)

    const bounds = leaflet.latLngBounds([])
    const groupedPoints = this.groupedPoints()

    groupedPoints.forEach(({ position, points }) => {
      const approximate = points.every((point) => point.approximate)
      const marker = leaflet.circleMarker(position, {
        radius: approximate ? 7 : 8,
        color: "#ffffff",
        weight: 3,
        fillColor: approximate ? "#2563eb" : "#f97316",
        fillOpacity: 1,
      }).addTo(this.map)

      marker.bindTooltip(this.markerLabel(points), {
        permanent: true,
        direction: "top",
        offset: [0, -10],
        opacity: 1,
        className: "supplier-map-marker-label",
      })

      if (points.length === 1) {
        marker.on("click", () => this.openPoint(points[0]))
      } else {
        marker.bindPopup(this.pointList(points), {
          className: "supplier-map-leaflet-popup",
          maxWidth: 360,
        })
      }
      bounds.extend(position)
    })

    if (groupedPoints.length === 1) {
      this.map.setView(groupedPoints[0].position, 13)
    } else if (groupedPoints.length > 1) {
      this.map.fitBounds(bounds, { padding: [52, 52], maxZoom: 13 })
    }

    requestAnimationFrame(() => this.map?.invalidateSize())
    this.hidePlaceholder()
  }

  enableInteractions() {
    if (!this.map) return

    ;["dragging", "scrollWheelZoom", "doubleClickZoom", "boxZoom", "keyboard", "touchZoom"].forEach((handlerName) => {
      this.map[handlerName]?.enable()
    })

    this.canvasTarget.classList.add("supplier-location-map__map--interactive")
    this.canvasTarget.tabIndex = 0
  }

  groupedPoints() {
    const groups = new Map()

    this.pointsValue.forEach((point) => {
      const lat = Number(point.lat)
      const lng = Number(point.lng)
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return

      const key = `${lat.toFixed(7)}:${lng.toFixed(7)}`
      const group = groups.get(key) || { position: [lat, lng], points: [] }
      group.points.push(point)
      groups.set(key, group)
    })

    return Array.from(groups.values())
  }

  markerLabel(points) {
    const firstName = String(points[0]?.supplier_name || "Fornecedor").trim()
    const value = points.length > 1 ? `${firstName} +${points.length - 1}` : firstName
    return value.length > 34 ? `${value.slice(0, 31)}...` : value
  }

  openPoint(point) {
    if (!point.google_maps_url) return

    const popup = window.open(point.google_maps_url, "_blank", "noopener,noreferrer")
    if (popup) popup.opener = null
  }

  pointList(points) {
    const content = document.createElement("div")
    content.className = "supplier-map-popup"

    points.forEach((point) => {
      const item = document.createElement("a")
      const name = document.createElement("strong")
      const location = document.createElement("span")
      item.className = "supplier-map-popup__item"
      item.href = point.google_maps_url || point.openstreetmap_url || "#"
      item.target = "_blank"
      item.rel = "noopener noreferrer"
      name.textContent = point.supplier_name || "Fornecedor"
      location.textContent = point.location_label || "Abrir localização"
      item.append(name, location)
      content.append(item)
    })

    return content
  }

  hidePlaceholder() {
    if (!this.hasPlaceholderTarget) return

    this.placeholderTarget.hidden = true
    this.placeholderTarget.classList.add("hidden")
  }

  showPlaceholder() {
    if (!this.hasPlaceholderTarget) return

    this.placeholderTarget.hidden = false
    this.placeholderTarget.classList.remove("hidden")
  }
}
