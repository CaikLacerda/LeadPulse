import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "placeholder"]

  static values = {
    apiKey: String,
    points: Array,
  }

  connect() {
    this.markers = []

    if (!this.hasApiKeyValue || !this.pointsValue.length) return

    this.loadGoogleMaps()
      .then(() => this.renderMap())
      .catch(() => this.showPlaceholder())
  }

  disconnect() {
    this.markers.forEach((marker) => marker.setMap(null))
    this.markers = []
  }

  loadGoogleMaps() {
    if (window.google?.maps) return Promise.resolve(window.google.maps)
    if (window.leadPulseGoogleMapsPromise) return window.leadPulseGoogleMapsPromise

    window.leadPulseGoogleMapsPromise = new Promise((resolve, reject) => {
      const callbackName = "__leadPulseGoogleMapsReady"
      window[callbackName] = () => resolve(window.google.maps)

      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(this.apiKeyValue)}&language=pt-BR&region=BR&callback=${callbackName}`
      script.async = true
      script.defer = true
      script.onerror = reject
      document.head.appendChild(script)
    })

    return window.leadPulseGoogleMapsPromise
  }

  renderMap() {
    if (!this.hasCanvasTarget) return

    const map = new window.google.maps.Map(this.canvasTarget, {
      center: { lat: -14.235004, lng: -51.92528 },
      zoom: 4,
      clickableIcons: false,
      fullscreenControl: false,
      mapTypeControl: false,
      streetViewControl: false,
    })

    const bounds = new window.google.maps.LatLngBounds()

    this.pointsValue.forEach((point) => {
      const lat = Number(point.lat)
      const lng = Number(point.lng)
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return

      const position = { lat, lng }
      const marker = new window.google.maps.Marker({
        map,
        position,
        title: point.supplier_name || "Fornecedor",
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          scale: 7,
          fillColor: "#f97316",
          fillOpacity: 1,
          strokeColor: "#ffffff",
          strokeWeight: 2,
        },
      })

      marker.addListener("click", () => this.openPoint(point))
      this.markers.push(marker)
      bounds.extend(position)
    })

    if (this.markers.length === 1) {
      map.setCenter(this.markers[0].getPosition())
      map.setZoom(13)
    } else if (this.markers.length > 1) {
      map.fitBounds(bounds, 48)
    }

    this.hidePlaceholder()
  }

  openPoint(point) {
    if (!point.google_maps_url) return

    const popup = window.open(point.google_maps_url, "_blank", "noopener,noreferrer")
    if (popup) popup.opener = null
  }

  hidePlaceholder() {
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")
  }

  showPlaceholder() {
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.remove("hidden")
  }
}
