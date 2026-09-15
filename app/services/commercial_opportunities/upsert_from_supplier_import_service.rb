module CommercialOpportunities
  class UpsertFromSupplierImportService
    def initialize(supplier_import:)
      @supplier_import = supplier_import
    end

    def call
      return 0 unless @supplier_import.supplier_validation?

      refresh_commercial_opportunity_schema
      created_or_updated = 0
      Array(@supplier_import.response_payload["records"]).each do |record|
        details = record["supplier_validation"]
        next unless details.is_a?(Hash)
        next unless commercially_interested?(record, details)

        callback_phone = details["callback_phone_informed"].presence
        next if callback_phone.blank?

        opportunity = @supplier_import.commercial_opportunities.find_or_initialize_by(
          user: @supplier_import.user,
          source_external_id: record["external_id"].to_s
        )
        attributes = {
          supplier_name: supplier_name(record),
          source_phone: record["validated_phone"].presence || record["phone_normalized"].presence || record["phone_original"],
          callback_phone: callback_phone,
          callback_phone_choice: details["callback_phone_choice"],
          callback_preferred_time: details["callback_preferred_time"],
          segment_name: details["segment_name"].presence || @supplier_import.segment_name
        }
        if opportunity.has_attribute?(:callback_preferred_at)
          attributes[:callback_preferred_at] = details["callback_preferred_at"]
        end
        opportunity.assign_attributes(attributes)
        opportunity.status = CommercialOpportunity::STATUS_PENDING if opportunity.new_record?
        opportunity.save!
        created_or_updated += 1
      end
      created_or_updated
    end

    private

    def commercially_interested?(record, details)
      return false if record["privacy_refusal_detected"].present?

      reviewed_result = reviewed_results_by_external_id[record["external_id"].to_s]
      return reviewed_result == "qualified_supplier" if reviewed_result.present?

      ActiveModel::Type::Boolean.new.cast(details["commercial_interest"]) == true
    end

    def reviewed_results_by_external_id
      @reviewed_results_by_external_id ||= @supplier_import.audit_reviews
        .order(:reviewed_at, :id)
        .each_with_object({}) do |review, results|
          results[review.record_external_id.to_s] = review.reviewed_result
        end
    end

    def refresh_commercial_opportunity_schema
      return if CommercialOpportunity.column_names.include?("callback_preferred_at")

      CommercialOpportunity.reset_column_information
    end

    def supplier_name(record)
      record["client_name"].presence ||
        record["supplier_name"].presence ||
        record["company_name"].presence ||
        "Fornecedor #{record['external_id']}"
    end
  end
end
