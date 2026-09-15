require "securerandom"

module SupplierDiscoverySearches
  class QueueRemoteSearchService
    Result = Struct.new(:success?, :search, :error_message, keyword_init: true)

    def initialize(user:, params:)
      @user = user
      @params = params.to_h.deep_symbolize_keys
    end

    def call
      raise ValidationApi::Error, "Gere o token da API antes de iniciar uma busca." if @user.validation_api_token_value.blank?

      payload = build_payload
      search = @user.supplier_discovery_searches.create!(
        search_id: "local_#{SecureRandom.uuid}",
        status: SupplierDiscoverySearch::LOCAL_STATUS_PENDING,
        segment_name: payload.fetch(:segment_name),
        region: payload[:region],
        request_payload: payload
      )
      SupplierDiscoverySearchJob.perform_later(search)

      Result.new(success?: true, search:)
    rescue ValidationApi::Error, ArgumentError => e
      Result.new(success?: false, error_message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error_message: e.record.errors.full_messages.to_sentence)
    rescue ActiveJob::EnqueueError => e
      search&.update(status: SupplierDiscoverySearch::LOCAL_STATUS_ERROR, error_message: e.message)
      Result.new(success?: false, search:, error_message: "Não foi possível colocar a busca na fila local.")
    end

    private

    def build_payload
      max_suppliers = Integer(@params[:max_suppliers].presence || 10)
      unless max_suppliers.between?(1, 50)
        raise ArgumentError, "A quantidade máxima deve estar entre 1 e 50."
      end

      {
        segment_name: @params[:segment_name].to_s.strip,
        region: @params[:region].presence,
        max_suppliers:,
        include_locations: true
      }.compact
    rescue ArgumentError => e
      raise e if e.message.include?("entre 1 e 50")

      raise ArgumentError, "Informe uma quantidade máxima válida."
    end
  end
end
