module SupplierImports
  class RemoteStatusMapper
    ACTIVE_REMOTE_STATUSES = %w[
      pending
      queued
      accepted
      processing
      in_progress
      in-progress
      dispatching
    ].freeze
    COMPLETED_REMOTE_STATUSES = %w[completed complete].freeze
    FAILED_REMOTE_STATUSES = %w[failed error cancelled canceled].freeze
    SUPPLIER_TERMINAL_OUTCOMES = %w[
      qualified_supplier
      wrong_company
      does_not_supply_segment
      not_interested
      inconclusive
      privacy_refusal
      not_answered
    ].freeze

    SUPPLIER_TERMINAL_CALL_RESULTS = %w[rejected inconclusive not_answered].freeze

    def initialize(supplier_import:)
      @supplier_import = supplier_import
    end

    def local_status(response, fallback_status:)
      remote_status = normalized_remote_status(response["batch_status"])

      if response["result_ready"] == true && !FAILED_REMOTE_STATUSES.include?(remote_status)
        return completed_with_failures?(response) ? SupplierImport::LOCAL_STATUS_ERROR : SupplierImport::LOCAL_STATUS_COMPLETED
      end

      case remote_status
      when *COMPLETED_REMOTE_STATUSES
        completed_with_failures?(response) ? SupplierImport::LOCAL_STATUS_ERROR : SupplierImport::LOCAL_STATUS_COMPLETED
      when *ACTIVE_REMOTE_STATUSES
        SupplierImport::LOCAL_STATUS_PROCESSING
      when *FAILED_REMOTE_STATUSES
        SupplierImport::LOCAL_STATUS_ERROR
      else
        fallback_status
      end
    end

    def stale_response?(response, current_status:, current_remote_status:)
      incoming_remote_status = normalized_remote_status(response["batch_status"])
      incoming_local_status = local_status(response, fallback_status: current_status)

      if absorbing_terminal_status?(current_status, current_remote_status)
        return true unless terminal_remote_status?(incoming_remote_status)

        return incoming_local_status != current_status
      end

      incoming_rank = terminal_local_status?(incoming_local_status) ? 30 : remote_status_rank(incoming_remote_status)
      remote_status_rank(current_remote_status) > incoming_rank
    end

    def error_message(response, status:)
      return nil unless status == SupplierImport::LOCAL_STATUS_ERROR

      if %w[cancelled canceled].include?(normalized_remote_status(response["batch_status"]))
        return "O lote foi cancelado antes da conclusão."
      end

      summary = response["summary"].is_a?(Hash) ? response["summary"] : {}
      total_records = response["total_records"].to_i

      if total_records.positive? && summary["invalid_phone"].to_i >= total_records
        return "Todos os registros foram encerrados por telefone inválido antes da ligação."
      end

      Array(response["records"]).filter_map { |record| record["observation"].presence }.first ||
        "O lote foi encerrado sem registros aptos para ligação."
    end

    private

    def terminal_local_status?(status)
      [ SupplierImport::LOCAL_STATUS_COMPLETED, SupplierImport::LOCAL_STATUS_ERROR ].include?(status)
    end

    def absorbing_terminal_status?(status, remote_status)
      return true if status == SupplierImport::LOCAL_STATUS_COMPLETED
      return terminal_remote_status?(normalized_remote_status(remote_status)) if status == SupplierImport::LOCAL_STATUS_ERROR

      false
    end

    def terminal_remote_status?(status)
      COMPLETED_REMOTE_STATUSES.include?(status) || FAILED_REMOTE_STATUSES.include?(status)
    end

    def remote_status_rank(status)
      normalized = normalized_remote_status(status)
      return 30 if terminal_remote_status?(normalized)
      return 20 if %w[processing in_progress in-progress].include?(normalized)
      return 10 if ACTIVE_REMOTE_STATUSES.include?(normalized)

      0
    end

    def normalized_remote_status(status)
      status.to_s.strip.downcase
    end

    def completed_with_failures?(response)
      total_records = response["total_records"].to_i
      return false if total_records.zero?
      return false if supplier_validation_with_terminal_outcome?(response)

      summary = response["summary"].is_a?(Hash) ? response["summary"] : {}
      confirmed_records = summary["confirmed_by_call"].to_i + summary["confirmed_by_whatsapp"].to_i + summary["confirmed_by_email"].to_i
      validated_records = summary["validated_records"].to_i
      failed_records = summary["failed_records"].to_i
      invalid_phone = summary["invalid_phone"].to_i
      all_records_failed = Array(response["records"]).presence&.all? do |record|
        %w[validation_failed invalid_phone error failed].include?(record["final_status"].to_s)
      end

      confirmed_records.zero? &&
        validated_records.zero? &&
        (failed_records >= total_records || invalid_phone >= total_records || all_records_failed)
    end

    def supplier_validation_with_terminal_outcome?(response)
      return false unless @supplier_import.supplier_validation?

      records = Array(response["records"])
      return false if records.empty?

      records.all? do |record|
        supplier_validation = record["supplier_validation"].is_a?(Hash) ? record["supplier_validation"] : {}
        outcome = supplier_validation["outcome"].to_s
        call_result = record["call_result"].to_s

        SUPPLIER_TERMINAL_OUTCOMES.include?(outcome) ||
          SUPPLIER_TERMINAL_CALL_RESULTS.include?(call_result) ||
          record["privacy_refusal_detected"] == true
      end
    end
  end
end
