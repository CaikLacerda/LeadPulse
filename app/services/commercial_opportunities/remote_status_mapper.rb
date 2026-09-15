module CommercialOpportunities
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

    def local_status(response, fallback_status:)
      remote_status = normalized_remote_status(response["batch_status"])
      if response["result_ready"] == true && !FAILED_REMOTE_STATUSES.include?(remote_status)
        return CommercialOpportunity::STATUS_COMPLETED
      end

      return CommercialOpportunity::STATUS_COMPLETED if COMPLETED_REMOTE_STATUSES.include?(remote_status)
      return CommercialOpportunity::STATUS_ERROR if FAILED_REMOTE_STATUSES.include?(remote_status)
      return CommercialOpportunity::STATUS_PROCESSING if ACTIVE_REMOTE_STATUSES.include?(remote_status)

      fallback_status
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

    def failed_remote_status?(status)
      FAILED_REMOTE_STATUSES.include?(normalized_remote_status(status))
    end

    def error_message(response, status:)
      return nil unless status == CommercialOpportunity::STATUS_ERROR

      response["error_message"].presence ||
        response["message"].presence ||
        ("A coleta comercial foi cancelada." if %w[cancelled canceled].include?(normalized_remote_status(response["batch_status"]))) ||
        "A coleta comercial foi encerrada com erro."
    end

    private

    def terminal_local_status?(status)
      [ CommercialOpportunity::STATUS_COMPLETED, CommercialOpportunity::STATUS_ERROR ].include?(status)
    end

    def absorbing_terminal_status?(status, remote_status)
      return true if status == CommercialOpportunity::STATUS_COMPLETED
      return terminal_remote_status?(normalized_remote_status(remote_status)) if status == CommercialOpportunity::STATUS_ERROR

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
  end
end
