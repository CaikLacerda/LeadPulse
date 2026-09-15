class SupplierDiscoverySearch < ApplicationRecord
  include HasDisplayCode

  LOCATION_FIELD_ALIASES = {
    "address" => %w[formatted_address full_address address street_address location_address google_address],
    "latitude" => %w[latitude lat],
    "longitude" => %w[longitude lng lon long],
    "google_maps_url" => %w[google_maps_url google_maps_uri googleMapsUri maps_url place_url],
    "google_place_id" => %w[google_place_id googlePlaceId place_id],
    "openstreetmap_url" => %w[openstreetmap_url osm_url],
    "osm_place_id" => %w[osm_place_id osmPlaceId],
    "location_provider" => %w[location_provider locationProvider],
    "location_precision" => %w[location_precision locationPrecision]
  }.freeze

  LOCAL_STATUS_PENDING = "pendente".freeze
  LOCAL_STATUS_PROCESSING = "processando".freeze
  LOCAL_STATUS_COMPLETED = "concluido".freeze
  LOCAL_STATUS_ERROR = "erro".freeze
  LOCAL_STATUSES = [
    LOCAL_STATUS_PENDING,
    LOCAL_STATUS_PROCESSING,
    LOCAL_STATUS_COMPLETED,
    LOCAL_STATUS_ERROR
  ].freeze

  belongs_to :user

  validates :search_id, presence: true, length: { maximum: 120 }
  validates :segment_name, presence: true, length: { maximum: 120 }
  validates :region, length: { maximum: 160 }, allow_blank: true
  validates :callback_phone, length: { maximum: 32 }, allow_blank: true
  validates :callback_contact_name, length: { maximum: 120 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: LOCAL_STATUSES }
  validates :total_suppliers, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [ LOCAL_STATUS_PENDING, LOCAL_STATUS_PROCESSING ]) }
  display_code_prefix "BS"

  def completed?
    status == LOCAL_STATUS_COMPLETED
  end

  def errored?
    status == LOCAL_STATUS_ERROR
  end

  def suppliers
    Array(response_payload["suppliers"])
  end

  def download_ready?
    results_xlsx_data.present?
  end

  def discarded_without_phone_count
    response_payload["discarded_suppliers_without_phone_count"].to_i
  end

  def download_content_type
    return "text/csv; charset=utf-8" if results_filename.to_s.downcase.ends_with?(".csv")

    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def download_filename
    extension = File.extname(results_filename.to_s).presence || ".csv"
    "busca-#{display_number}#{extension}"
  end

  def valid_supplier_candidates
    suppliers.each_with_index.filter_map do |supplier, index|
      next if supplier["supplier_name"].blank? || supplier["phone"].blank?

      {
        external_id: "BUSCA-#{display_number}-#{(index + 1).to_s.rjust(3, '0')}",
        supplier_name: supplier["supplier_name"],
        phone: supplier["phone"],
        email: supplier["email"].presence,
        city: supplier["city"].presence,
        state: supplier["state"].presence,
        notes: supplier["notes"].presence,
        custom_fields: compact_custom_fields(supplier)
      }.compact
    end
  end

  def invalid_supplier_candidates_count
    suppliers.size - valid_supplier_candidates.size
  end

  def pending?
    status == LOCAL_STATUS_PENDING
  end

  def processing?
    status == LOCAL_STATUS_PROCESSING
  end

  def active?
    pending? || processing?
  end

  private

  def compact_custom_fields(supplier)
    fields = {
      "website" => supplier["website"].presence,
      "address" => supplier_location_value(supplier, "address"),
      "source_urls" => Array(supplier["source_urls"]).presence&.join(" | "),
      "discovery_confidence" => supplier["discovery_confidence"],
      "latitude" => supplier_location_value(supplier, "latitude"),
      "longitude" => supplier_location_value(supplier, "longitude"),
      "google_maps_url" => supplier_location_value(supplier, "google_maps_url"),
      "google_place_id" => supplier_location_value(supplier, "google_place_id"),
      "openstreetmap_url" => supplier_location_value(supplier, "openstreetmap_url"),
      "osm_place_id" => supplier_location_value(supplier, "osm_place_id"),
      "location_provider" => supplier_location_value(supplier, "location_provider"),
      "location_precision" => supplier_location_value(supplier, "location_precision")
    }.compact

    fields.presence
  end

  def supplier_location_value(supplier, key)
    location = supplier["location"].is_a?(Hash) ? supplier["location"] : {}
    LOCATION_FIELD_ALIASES.fetch(key, [ key ]).filter_map do |field|
      supplier[field].presence || location[field].presence
    end.first
  end
end
