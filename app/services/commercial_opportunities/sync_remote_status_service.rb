module CommercialOpportunities
  class SyncRemoteStatusService
    def initialize(user:, commercial_opportunity:)
      @user = user
      @commercial_opportunity = commercial_opportunity
    end

    def call
      raise ValidationApi::Error, "Gere o token da API antes de consultar o retorno comercial." if @user.validation_api_token_value.blank?
      raise ValidationApi::Error, "Este retorno comercial ainda não foi iniciado." if @commercial_opportunity.remote_batch_id.blank?

      refresh_commercial_opportunity_schema
      requested_batch_id = @commercial_opportunity.remote_batch_id
      response = show_remote_batch_service.call(
        api_token: @user.validation_api_token_value,
        batch_id: requested_batch_id
      )
      apply_response!(response, requested_batch_id: requested_batch_id)
      response
    end

    private

    def show_remote_batch_service
      ValidationApi::CommercialValidations::ShowBatchService.new
    end

    def apply_response!(response, requested_batch_id:)
      @commercial_opportunity.with_lock do
        return if @commercial_opportunity.remote_batch_id != requested_batch_id

        mapper = RemoteStatusMapper.new
        if mapper.stale_response?(
          response,
          current_status: @commercial_opportunity.status,
          current_remote_status: @commercial_opportunity.remote_batch_status
        )
          @commercial_opportunity.update!(last_synced_at: Time.current)
          return
        end

        record = Array(response["records"]).first || {}
        details = record["commercial_validation"].is_a?(Hash) ? record["commercial_validation"] : {}
        status = mapper.local_status(response, fallback_status: @commercial_opportunity.status)
        attributes = {
          response_payload: response,
          remote_batch_status: response["batch_status"].presence || @commercial_opportunity.remote_batch_status,
          status: status,
          result_ready: @commercial_opportunity.result_ready? || response["result_ready"] == true,
          callback_preferred_time: details["preferred_callback_time"].presence || @commercial_opportunity.callback_preferred_time,
          product_specification: details["product_specification"].presence || @commercial_opportunity.product_specification,
          unit_price: details["unit_price"].presence || @commercial_opportunity.unit_price,
          lot_price_ranges: details["lot_price_ranges"].presence || @commercial_opportunity.lot_price_ranges,
          minimum_order: details["minimum_order"].presence || @commercial_opportunity.minimum_order,
          outcome: details["outcome"].presence || @commercial_opportunity.outcome,
          last_synced_at: Time.current,
          finished_at: response["finished_at"].presence || @commercial_opportunity.finished_at,
          error_message: mapper.error_message(response, status: status)
        }
        normalized_attributes = {
          normalized_product_specification: details["normalized_product_specification"],
          normalized_unit_price: details["normalized_unit_price"],
          normalized_lot_price_ranges: details["normalized_lot_price_ranges"],
          normalized_minimum_order: details["normalized_minimum_order"],
          normalization_source: details["normalization_source"]
        }
        normalized_attributes.each do |attribute, value|
          next unless @commercial_opportunity.has_attribute?(attribute)

          attributes[attribute] = value.presence || @commercial_opportunity.public_send(attribute)
        end
        if @commercial_opportunity.has_attribute?(:callback_preferred_at)
          attributes[:callback_preferred_at] = details["preferred_callback_at"].presence || @commercial_opportunity.callback_preferred_at
        end
        @commercial_opportunity.update!(attributes)
      end
    end

    def refresh_commercial_opportunity_schema
      expected_columns = %w[
        callback_preferred_at
        normalized_product_specification
        normalized_unit_price
        normalized_lot_price_ranges
        normalized_minimum_order
        normalization_source
      ]
      return if expected_columns.all? { |column| @commercial_opportunity.has_attribute?(column) }

      CommercialOpportunity.reset_column_information
      @commercial_opportunity.reload
    end
  end
end
