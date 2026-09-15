require "csv"

module SupplierImports
  class ExportResultCsvService
    class Error < StandardError; end
    DISPLAY_TIME_ZONE = "America/Sao_Paulo".freeze
    REVIEWED_SUPPLIER_OUTCOMES = %w[
      qualified_supplier
      wrong_company
      does_not_supply_segment
      not_interested
      privacy_refusal
      not_answered
      inconclusive
    ].freeze

    def initialize(supplier_import:)
      @supplier_import = supplier_import
    end

    def call
      records = Array(@supplier_import.response_payload["records"])
      raise Error, "Esse lote ainda não possui registros retornados para exportação." if records.blank?

      rows = records.map { |record| build_row(record) }
      headers = rows.first.keys

      content = CSV.generate(headers: true) do |csv|
        csv << headers
        rows.each do |row|
          csv << headers.map { |header| Spreadsheets::CellSanitizer.sanitize(row[header]) }
        end
      end

      {
        filename: @supplier_import.export_filename,
        content: content,
        content_type: "text/csv; charset=utf-8"
      }
    end

    private

    def build_row(record)
      if @supplier_import.supplier_validation?
        supplier_row(record)
      else
        cadastral_row(record)
      end
    end

    def cadastral_row(record)
      {
        header(:record) => record["external_id"],
        header(:company) => supplier_name_for(record),
        header(:cnpj) => cnpj_for(record),
        header(:phone_original) => phone_original_for(record),
        header(:phone_validated) => phone_validated_for(record),
        header(:phone_type) => phone_type_label(record["phone_type"]),
        header(:result) => result_label(record),
        header(:call_status) => call_status_label(record["call_status"]),
        header(:confirmation_source) => confirmation_source_label(record["confirmation_source"]),
        header(:phone_confirmed) => boolean_label(record["phone_confirmed"]),
        header(:observation) => observation_for(record),
        header(:finished_at) => finished_at_label(record)
      }
    end

    def supplier_row(record)
      supplier_validation = normalized_supplier_validation(record)

      {
        header(:record) => record["external_id"],
        header(:company) => supplier_name_for(record),
        header(:segment) => supplier_validation["segment_name"],
        header(:phone_original) => phone_original_for(record),
        header(:phone_validated) => phone_validated_for(record),
        header(:phone_type) => phone_type_label(record["phone_type"]),
        header(:phone_belongs_to_company) => boolean_label(supplier_validation["phone_belongs_to_company"]),
        header(:supplies_segment) => boolean_label(supplier_validation["supplies_segment"]),
        header(:commercial_interest) => boolean_label(supplier_validation["commercial_interest"]),
        header(:callback_phone) => supplier_validation["callback_phone_informed"],
        header(:callback_preferred_time) => supplier_validation["callback_preferred_time"],
        header(:callback_preferred_at) => callback_preferred_at_label(supplier_validation),
        header(:result) => result_label(record),
        header(:call_status) => call_status_label(record["call_status"]),
        header(:confirmation_source) => confirmation_source_label(record["confirmation_source"]),
        header(:observation) => observation_for(record),
        header(:finished_at) => finished_at_label(record)
      }
    end

    def supplier_name_for(record)
      record["client_name"].presence || record["company_name"].presence || record["supplier_name"].presence || record["external_id"]
    end

    def cnpj_for(record)
      record["cnpj_original"].presence || record["cnpj_normalized"].presence
    end

    def phone_original_for(record)
      record["phone_original"].presence || record["last_phone_dialed"].presence
    end

    def phone_validated_for(record)
      record["validated_phone"].presence || record["phone_normalized"].presence
    end

    def observation_for(record)
      record["observation"].presence || record["transcript_summary"].presence
    end

    def finished_at_label(record)
      timestamp =
        parse_time(record["finished_at"]) ||
        latest_attempt_time(record) ||
        @supplier_import.finished_at

      timestamp&.in_time_zone(DISPLAY_TIME_ZONE)&.strftime("%d/%m/%Y %H:%M")
    end

    def callback_preferred_at_label(supplier_validation)
      timestamp = parse_time(supplier_validation["callback_preferred_at"])
      timestamp&.in_time_zone(DISPLAY_TIME_ZONE)&.strftime("%d/%m/%Y %H:%M")
    end

    def latest_attempt_time(record)
      Array(record["call_attempts"]).filter_map do |attempt|
        parse_time(attempt["finished_at"]) || parse_time(attempt["started_at"])
      end.max
    end

    def parse_time(value)
      return if value.blank?

      return value.in_time_zone("UTC") if value.respond_to?(:in_time_zone) && !value.is_a?(String)

      raw = value.to_s.strip
      return if raw.blank?

      if raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/) && raw !~ /(z|[+-]\d{2}:\d{2})\z/i
        Time.find_zone!("UTC").parse(raw)
      else
        Time.zone.parse(raw)
      end
    rescue ArgumentError, TypeError
      nil
    end

    def result_label(record)
      return translate_value(:results, "privacy_refusal") if record["privacy_refusal_detected"].present?

      code = reviewed_result_for(record) ||
        if @supplier_import.supplier_validation?
          normalized_supplier_validation(record)["outcome"].presence ||
            record["business_status"].presence ||
            record["final_status"].presence ||
            record["call_result"].presence
        else
          record["business_status"].presence ||
            record["final_status"].presence ||
            record["call_result"].presence
        end

      translate_value(:results, code)
    end

    def call_status_label(code)
      translate_value(:call_statuses, code)
    end

    def confirmation_source_label(code)
      translate_value(:confirmation_sources, code)
    end

    def phone_type_label(code)
      translate_value(:phone_types, code)
    end

    def boolean_label(value)
      value = normalize_boolean(value)
      return "" if value.nil?

      value ? value_label(:yes) : value_label(:no)
    end

    def normalized_supplier_validation(record)
      raw = record["supplier_validation"].is_a?(Hash) ? record["supplier_validation"].dup : {}
      phone_belongs = normalize_boolean(raw["phone_belongs_to_company"])
      supplies_segment = normalize_boolean(raw["supplies_segment"])
      commercial_interest = normalize_boolean(raw["commercial_interest"])
      reviewed_result = reviewed_result_for(record) unless record["privacy_refusal_detected"].present?

      if reviewed_result.present?
        outcome = reviewed_result if REVIEWED_SUPPLIER_OUTCOMES.include?(reviewed_result)
        phone_belongs = nil
        supplies_segment = nil
        commercial_interest = nil
      else
        outcome = raw["outcome"].presence
        outcome ||= infer_supplier_outcome_from_flags(
          phone_belongs: phone_belongs,
          supplies_segment: supplies_segment,
          commercial_interest: commercial_interest
        )
        outcome ||= infer_supplier_outcome_from_record(record)
      end

      case outcome
      when "wrong_company"
        phone_belongs = false
      when "does_not_supply_segment"
        phone_belongs = true if phone_belongs.nil?
        supplies_segment = false
      when "not_interested"
        phone_belongs = true if phone_belongs.nil?
        supplies_segment = true if supplies_segment.nil?
        commercial_interest = false
      when "qualified_supplier"
        phone_belongs = true
        supplies_segment = true
        commercial_interest = true
      end

      raw.merge(
        "segment_name" => raw["segment_name"].presence || @supplier_import.segment_name,
        "phone_belongs_to_company" => phone_belongs,
        "supplies_segment" => supplies_segment,
        "commercial_interest" => commercial_interest,
        "outcome" => outcome
      )
    end

    def infer_supplier_outcome_from_flags(phone_belongs:, supplies_segment:, commercial_interest:)
      return "wrong_company" if phone_belongs == false
      return "does_not_supply_segment" if supplies_segment == false
      return "not_interested" if commercial_interest == false
      return "qualified_supplier" if [ phone_belongs, supplies_segment, commercial_interest ].all?(true)

      nil
    end

    def infer_supplier_outcome_from_record(record)
      final_status = record["final_status"].to_s
      return final_status if REVIEWED_SUPPLIER_OUTCOMES.include?(final_status)
      return "qualified_supplier" if record["final_status"].to_s == "validated"
      return "not_answered" if record["call_result"].to_s == "not_answered" || record["call_status"].to_s == "not_answered"
      return "inconclusive" if record["call_result"].to_s == "inconclusive" || record["business_status"].to_s == "inconclusive_call"

      nil
    end

    def reviewed_result_for(record)
      reviewed_results_by_external_id[record["external_id"].to_s]
    end

    def reviewed_results_by_external_id
      @reviewed_results_by_external_id ||= @supplier_import.audit_reviews
        .order(:reviewed_at, :id)
        .each_with_object({}) do |review, results|
          results[review.record_external_id.to_s] = review.reviewed_result
        end
    end

    def normalize_boolean(value)
      case value
      when true, false
        value
      when String
        normalized = value.strip.downcase
        return true if %w[true t 1 yes sim].include?(normalized)
        return false if %w[false f 0 no nao não].include?(normalized)

        nil
      when Numeric
        return false if value.zero?

        true
      else
        nil
      end
    end

    def translate_value(scope, code)
      return "" if code.blank?

      I18n.t(
        "supplier_imports.export.#{scope}.#{code}",
        default: I18n.t("validation_audits.index.results.#{code}", default: code.to_s.tr("_", " ").capitalize)
      )
    end

    def value_label(key)
      I18n.t("supplier_imports.export.values.#{key}")
    end

    def header(key)
      I18n.t("supplier_imports.export.headers.#{key}")
    end
  end
end
