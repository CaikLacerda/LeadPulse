module SupplierImports
  class AuditEntriesService < ApplicationService
    Entry = Struct.new(
      :lot_code,
      :lot_id,
      :supplier_name,
      :workflow_kind,
      :source,
      :occurred_at,
      :result_code,
      :observation,
      :customer_transcript,
      :assistant_transcript,
      :conversation_turns,
      :summary,
      :provider_call_id,
      :attempt_number,
      :recording_url,
      :privacy_refusal_detected,
      :privacy_refusal_reason,
      :evidence_anonymized,
      :record_external_id,
      :review,
      keyword_init: true
    )

    def initialize(user:)
      @user = user
    end

    def call
      preload_reviews

      @user.supplier_imports.order(created_at: :desc).flat_map do |supplier_import|
        entries_for_import(supplier_import)
      end.sort_by { |entry| entry.occurred_at || Time.zone.at(0) }.reverse
    end

    private

    def entries_for_import(supplier_import)
      Array(supplier_import.response_payload["records"]).flat_map do |record|
        call_attempts = Array(record["call_attempts"])

        if call_attempts.any?
          call_attempts.map { |attempt| build_attempt_entry(supplier_import, record, attempt) }.compact
        else
          fallback_entry = build_record_entry(supplier_import, record)
          fallback_entry ? [ fallback_entry ] : []
        end
      end
    end

    def build_attempt_entry(supplier_import, record, attempt)
      Entry.new(
        lot_code: supplier_import.display_code,
        lot_id: supplier_import.id,
        supplier_name: supplier_name_for(record),
        workflow_kind: supplier_import.workflow_kind,
        source: supplier_import.source,
        occurred_at: parse_time(attempt["finished_at"]) || parse_time(attempt["started_at"]) || supplier_import.finished_at || supplier_import.created_at,
        result_code: attempt["result"].presence || record["business_status"].presence || record["final_status"].presence,
        observation: attempt["observation"].presence || record["observation"].presence,
        customer_transcript: attempt["customer_transcript"].presence || record["customer_transcript"].presence,
        assistant_transcript: attempt["assistant_transcript"].presence || record["assistant_transcript"].presence,
        conversation_turns: conversation_turns_for(attempt, record),
        summary: attempt["transcript_summary"].presence || record["transcript_summary"].presence || record["observation"].presence,
        provider_call_id: attempt["provider_call_id"],
        attempt_number: attempt["attempt_number"],
        recording_url: attempt["recording_url"],
        privacy_refusal_detected: attempt["privacy_refusal_detected"].presence || record["privacy_refusal_detected"].presence,
        privacy_refusal_reason: attempt["privacy_refusal_reason"].presence || record["privacy_refusal_reason"].presence,
        evidence_anonymized: attempt["evidence_anonymized"].presence || record["evidence_anonymized"].presence,
        record_external_id: record["external_id"],
        review: review_for(supplier_import, record["external_id"], attempt["provider_call_id"], attempt["attempt_number"])
      )
    end

    def build_record_entry(supplier_import, record)
      return if [
        record["customer_transcript"],
        record["assistant_transcript"],
        record["conversation_turns"],
        record["transcript_summary"],
        record["observation"]
      ].all?(&:blank?)

      Entry.new(
        lot_code: supplier_import.display_code,
        lot_id: supplier_import.id,
        supplier_name: supplier_name_for(record),
        workflow_kind: supplier_import.workflow_kind,
        source: supplier_import.source,
        occurred_at: parse_time(record["finished_at"]) || supplier_import.finished_at || supplier_import.created_at,
        result_code: record["call_result"].presence || record["business_status"].presence || record["final_status"].presence,
        observation: record["observation"].presence,
        customer_transcript: record["customer_transcript"],
        assistant_transcript: record["assistant_transcript"],
        conversation_turns: conversation_turns_for(record),
        summary: record["transcript_summary"].presence || record["observation"].presence,
        provider_call_id: nil,
        attempt_number: nil,
        recording_url: nil,
        privacy_refusal_detected: record["privacy_refusal_detected"],
        privacy_refusal_reason: record["privacy_refusal_reason"],
        evidence_anonymized: record["evidence_anonymized"],
        record_external_id: record["external_id"],
        review: review_for(supplier_import, record["external_id"], nil, nil)
      )
    end

    def preload_reviews
      @reviews_by_key = @user.audit_reviews.includes(:supplier_import).index_by do |review|
        review_key(review.supplier_import_id, review.record_external_id, review.provider_call_id, review.attempt_number)
      end
    end

    def review_for(supplier_import, record_external_id, provider_call_id, attempt_number)
      @reviews_by_key[review_key(supplier_import.id, record_external_id, provider_call_id, attempt_number)]
    end

    def review_key(supplier_import_id, record_external_id, provider_call_id, attempt_number)
      [
        supplier_import_id.to_s,
        record_external_id.to_s,
        provider_call_id.to_s,
        attempt_number.to_s
      ].join(":")
    end

    def conversation_turns_for(primary, fallback = nil)
      raw_turns = primary["conversation_turns"].presence || fallback&.dig("conversation_turns")

      Array(raw_turns).filter_map do |raw_turn|
        next unless raw_turn.respond_to?(:to_h)

        turn = raw_turn.to_h.stringify_keys
        next unless %w[user assistant].include?(turn["role"])
        next if turn["transcript"].blank?

        turn.slice(
          "sequence",
          "role",
          "transcript",
          "question_id",
          "semantic_value",
          "confidence",
          "interrupted",
          "audio_played_ms"
        )
      end
    end

    def supplier_name_for(record)
      record["client_name"].presence || record["company_name"].presence || record["external_id"].presence || "Registro"
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
