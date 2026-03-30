class SupplierDiscoverySearch < ApplicationRecord
  include HasDisplayCode

  LOCAL_STATUS_COMPLETED = 'concluido'.freeze
  LOCAL_STATUS_ERROR = 'erro'.freeze

  belongs_to :user

  validates :search_id, presence: true
  validates :segment_name, presence: true
  validates :status, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  display_code_prefix 'BS'

  def completed?
    status == LOCAL_STATUS_COMPLETED
  end

  def errored?
    status == LOCAL_STATUS_ERROR
  end

  def suppliers
    Array(response_payload['suppliers'])
  end

  def download_ready?
    results_xlsx_data.present?
  end

  def discarded_without_phone_count
    response_payload['discarded_suppliers_without_phone_count'].to_i
  end

  def download_content_type
    return 'text/csv; charset=utf-8' if results_filename.to_s.downcase.ends_with?('.csv')

    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  end

  def download_filename
    extension = File.extname(results_filename.to_s).presence || '.csv'
    "busca-#{display_number}#{extension}"
  end

  def valid_supplier_candidates
    suppliers.each_with_index.filter_map do |supplier, index|
      next if supplier['supplier_name'].blank? || supplier['phone'].blank?

      {
        external_id: "BUSCA-#{display_number}-#{(index + 1).to_s.rjust(3, '0')}",
        supplier_name: supplier['supplier_name'],
        phone: supplier['phone'],
        email: supplier['email'].presence,
        city: supplier['city'].presence,
        state: supplier['state'].presence,
        notes: supplier['notes'].presence,
        custom_fields: compact_custom_fields(supplier)
      }.compact
    end
  end

  def invalid_supplier_candidates_count
    suppliers.size - valid_supplier_candidates.size
  end

  private

  def compact_custom_fields(supplier)
    fields = {
      'website' => supplier['website'].presence,
      'source_urls' => Array(supplier['source_urls']).presence&.join(' | '),
      'discovery_confidence' => supplier['discovery_confidence']
    }.compact

    fields.presence
  end
end
