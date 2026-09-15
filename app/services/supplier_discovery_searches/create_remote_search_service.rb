require "csv"

module SupplierDiscoverySearches
  class CreateRemoteSearchService
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

    Result = Struct.new(:success?, :search, :error_message, keyword_init: true)

    def initialize(
      search:,
      remote_service: ValidationApi::SupplierDiscovery::CreateSearchService.new
    )
      @search = search
      @user = search.user
      @remote_service = remote_service
    end

    def call
      raise ValidationApi::Error, "Gere o token da API antes de iniciar uma busca." if @user.validation_api_token_value.blank?

      payload = @search.request_payload.deep_symbolize_keys
      raw_response = @remote_service.call(
        api_token: @user.validation_api_token_value,
        payload: payload
      )
      response = filtered_response(raw_response)
      results_file = build_results_file(@search, response)
      @search.update!(
        search_id: response["search_id"],
        status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
        mode: response["mode"],
        segment_name: response["segment_name"],
        region: response["region"],
        total_suppliers: response["total_suppliers"] || Array(response["suppliers"]).size,
        generated_at: response["generated_at"],
        request_payload: payload,
        response_payload: response,
        results_xlsx_data: results_file[:body],
        results_filename: results_file[:filename],
        error_message: nil
      )

      Result.new(success?: true, search: @search)
    rescue ValidationApi::Error => e
      mark_as_failed(e.message)
    rescue ActiveRecord::RecordInvalid => e
      mark_as_failed(e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Rails.logger.error(
        "Unexpected supplier discovery failure | search_id=#{@search.id} " \
        "error=#{e.class}: #{e.message}"
      )
      mark_as_failed("Não foi possível concluir a busca de fornecedores.")
    end

    private

    def mark_as_failed(message)
      @search.reload
      @search.update_columns(
        status: SupplierDiscoverySearch::LOCAL_STATUS_ERROR,
        error_message: message,
        updated_at: Time.current
      )
      Result.new(success?: false, search: @search, error_message: message)
    end

    def filtered_response(raw_response)
      suppliers = Array(raw_response["suppliers"])
      filtered_suppliers = suppliers.select { |supplier| supplier["phone"].present? }
      discarded_count = suppliers.size - filtered_suppliers.size

      {
        "search_id" => raw_response["search_id"],
        "mode" => raw_response["mode"],
        "segment_name" => raw_response["segment_name"],
        "region" => raw_response["region"],
        "generated_at" => raw_response["generated_at"],
        "total_suppliers" => filtered_suppliers.size,
        "suppliers" => filtered_suppliers,
        "downloadable_file_url" => raw_response["downloadable_file_url"],
        "message" => raw_response["message"],
        "discarded_suppliers_without_phone_count" => discarded_count
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
        address
        city
        state
        latitude
        longitude
        google_maps_url
        google_place_id
        openstreetmap_url
        osm_place_id
        location_provider
        location_precision
        source_urls
        discovery_confidence
        notes
      ]

      content = CSV.generate(headers: true) do |csv|
        csv << headers

        Array(response["suppliers"]).each do |supplier|
          csv << [
            search.display_code,
            response["segment_name"],
            response["region"],
            supplier["supplier_name"],
            supplier["phone"],
            supplier["website"],
            supplier_location_value(supplier, "address"),
            supplier["city"],
            supplier["state"],
            supplier_location_value(supplier, "latitude"),
            supplier_location_value(supplier, "longitude"),
            supplier_location_value(supplier, "google_maps_url"),
            supplier_location_value(supplier, "google_place_id"),
            supplier_location_value(supplier, "openstreetmap_url"),
            supplier_location_value(supplier, "osm_place_id"),
            supplier_location_value(supplier, "location_provider"),
            supplier_location_value(supplier, "location_precision"),
            Array(supplier["source_urls"]).join(" | "),
            supplier["discovery_confidence"],
            supplier["notes"]
          ].map { |value| Spreadsheets::CellSanitizer.sanitize(value) }
        end
      end

      {
        body: content,
        filename: search.download_filename
      }
    end

    def supplier_location_value(supplier, key)
      location = supplier["location"].is_a?(Hash) ? supplier["location"] : {}
      LOCATION_FIELD_ALIASES.fetch(key, [ key ]).filter_map do |field|
        supplier[field].presence || location[field].presence
      end.first
    end
  end
end
