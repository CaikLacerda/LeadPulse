class ThirdPartyOperator < ApplicationRecord
  SERVICE_TYPES = {
    telephony: "Telefonia",
    artificial_intelligence: "Inteligência artificial",
    maps: "Mapas/geolocalização",
    email: "E-mail",
    hosting: "Hospedagem/armazenamento",
    other: "Outro"
  }.freeze

  belongs_to :user

  validates :name, :service_type, presence: true
  validates :service_type, inclusion: { in: SERVICE_TYPES.keys.map(&:to_s) }
  validates :name, :technical_owner, length: { maximum: 255 }, allow_blank: true
  validates :country, length: { maximum: 120 }, allow_blank: true
  validates :contract_reference, length: { maximum: 255 }, allow_blank: true
  validates :data_shared, :purpose, length: { maximum: 4_000 }, allow_blank: true

  def service_type_label
    SERVICE_TYPES.fetch(service_type.to_sym, service_type.to_s.humanize)
  end
end
