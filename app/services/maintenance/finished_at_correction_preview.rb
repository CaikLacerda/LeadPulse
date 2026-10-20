module Maintenance
  # Prévia (somente leitura) da correção histórica de finished_at. Registros sincronizados
  # antes de ValidationApi::Timestamp gravaram horários sem fuso como se fossem de
  # America/Sao_Paulo. Aqui cada lote e coleta comercial é recalculado a partir do payload
  # original e comparado com o valor atual, sem alterar nada.
  class FinishedAtCorrectionPreview < ApplicationService
    LONG_RUN = 2.days

    Row = Struct.new(
      :kind,
      :id,
      :account_id,
      :code,
      :started_at,
      :current_value,
      :payload_value,
      :new_value,
      :anomalies,
      keyword_init: true
    ) do
      def difference
        return if current_value.blank? || new_value.blank?

        new_value - current_value
      end

      def change?
        new_value.present? && new_value != current_value
      end
    end

    def initialize(account: nil)
      @account = account
    end

    def call
      supplier_import_rows + commercial_opportunity_rows
    end

    private

    def supplier_import_rows
      scoped(SupplierImport).order(:id).filter_map do |supplier_import|
        build_row(
          kind: "Lote",
          record: supplier_import,
          code: supplier_import.display_code,
          started_at: supplier_import.validation_started_at
        )
      end
    end

    def commercial_opportunity_rows
      scoped(CommercialOpportunity).includes(:supplier_import).order(:id).filter_map do |opportunity|
        build_row(
          kind: "Coleta comercial",
          record: opportunity,
          code: "#{opportunity.display_code} (#{opportunity.supplier_import&.display_code || 'sem lote'})",
          started_at: opportunity.started_at
        )
      end
    end

    def scoped(model)
      @account ? model.where(account_id: @account.id) : model.all
    end

    def build_row(kind:, record:, code:, started_at:)
      payload = record.response_payload.is_a?(Hash) ? record.response_payload : {}
      payload_value = payload["finished_at"].presence
      return if record.finished_at.blank? && payload_value.blank?

      new_value = ValidationApi::Timestamp.parse(payload_value) || record.finished_at

      Row.new(
        kind: kind,
        id: record.id,
        account_id: record.account_id,
        code: code,
        started_at: started_at,
        current_value: record.finished_at,
        payload_value: payload_value,
        new_value: new_value,
        anomalies: anomalies_for(record, started_at, payload_value, new_value)
      )
    end

    def anomalies_for(record, started_at, payload_value, new_value)
      anomalies = []
      anomalies << "sem finished_at no payload" if payload_value.blank?
      anomalies << "finished_at do payload ilegível" if payload_value.present? && ValidationApi::Timestamp.parse(payload_value).blank?
      if started_at.present? && new_value.present?
        anomalies << "termina antes de começar" if new_value < started_at
        anomalies << "duração acima de #{LONG_RUN.inspect}" if new_value - started_at > LONG_RUN
      end
      anomalies << "termina antes da criação" if new_value.present? && new_value < record.created_at
      anomalies
    end
  end
end
