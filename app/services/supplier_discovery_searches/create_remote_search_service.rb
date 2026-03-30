require 'csv'

module SupplierDiscoverySearches
  class CreateRemoteSearchService
    Result = Struct.new(:success?, :search, :error_message, keyword_init: true)

    def initialize(user:, params:)
      @user = user
      @params = params.to_h.deep_symbolize_keys
    end

    def call
      raise ValidationApi::Error, 'Gere o token da API antes de iniciar uma busca.' if @user.validation_api_token_value.blank?

      payload = build_payload
      raw_response = ValidationApi::SupplierDiscovery::CreateSearchService.new.call(
        api_token: @user.validation_api_token_value,
        payload: payload
      )
      response = filtered_response(raw_response)
      search = @user.supplier_discovery_searches.create!(
        search_id: response['search_id'],
        status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
        mode: response['mode'],
        segment_name: response['segment_name'],
        region: response['region'],
        callback_phone: response['callback_phone'],
        callback_contact_name: response['callback_contact_name'],
        total_suppliers: response['total_suppliers'] || Array(response['suppliers']).size,
        generated_at: response['generated_at'],
        request_payload: payload,
        response_payload: response
      )
      results_file = build_results_file(search, response)
      search.update!(
        results_xlsx_data: results_file[:body],
        results_filename: results_file[:filename]
      )

      Result.new(success?: true, search:)
    rescue ValidationApi::Error => e
      Result.new(success?: false, error_message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error_message: e.record.errors.full_messages.to_sentence)
    end

    private

    def build_payload
      {
        segment_name: @params[:segment_name],
        region: @params[:region].presence,
        callback_phone: @params[:callback_phone],
        callback_contact_name: @params[:callback_contact_name].presence,
        max_suppliers: @params[:max_suppliers].presence || 10
      }.compact
    end

    def filtered_response(raw_response)
      suppliers = Array(raw_response['suppliers'])
      filtered_suppliers = suppliers.select { |supplier| supplier['phone'].present? }
      discarded_count = suppliers.size - filtered_suppliers.size

      {
        'search_id' => raw_response['search_id'],
        'mode' => raw_response['mode'],
        'segment_name' => raw_response['segment_name'],
        'region' => raw_response['region'],
        'callback_phone' => raw_response['callback_phone'],
        'callback_contact_name' => raw_response['callback_contact_name'],
        'generated_at' => raw_response['generated_at'],
        'total_suppliers' => filtered_suppliers.size,
        'suppliers' => filtered_suppliers,
        'downloadable_file_url' => raw_response['downloadable_file_url'],
        'message' => raw_response['message'],
        'discarded_suppliers_without_phone_count' => discarded_count
      }
    end

    def build_results_file(search, response)
      headers = %w[
        search_id
        segment_name
        region
        supplier_name
        phone
        website
        city
        state
        source_urls
        discovery_confidence
        notes
        callback_phone
        callback_contact_name
      ]

      content = CSV.generate(headers: true) do |csv|
        csv << headers

        Array(response['suppliers']).each do |supplier|
          csv << [
            search.display_code,
            response['segment_name'],
            response['region'],
            supplier['supplier_name'],
            supplier['phone'],
            supplier['website'],
            supplier['city'],
            supplier['state'],
            Array(supplier['source_urls']).join(' | '),
            supplier['discovery_confidence'],
            supplier['notes'],
            response['callback_phone'],
            response['callback_contact_name']
          ]
        end
      end

      {
        body: content,
        filename: search.download_filename
      }
    end
  end
end
