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
      :summary,
      :provider_call_id,
      :attempt_number,
      :record_external_id,
      keyword_init: true
    )

    def initialize(user:)
      @user = user
    end

    def call
      @user.supplier_imports.order(created_at: :desc).flat_map do |supplier_import|
        entries_for_import(supplier_import)
      end.sort_by { |entry| entry.occurred_at || Time.zone.at(0) }.reverse
    end

    private

    def entries_for_import(supplier_import)
      Array(supplier_import.response_payload['records']).flat_map do |record|
        call_attempts = Array(record['call_attempts'])

        if call_attempts.any?
          call_attempts.map { |attempt| build_attempt_entry(supplier_import, record, attempt) }.compact
        else
          fallback_entry = build_record_entry(supplier_import, record)
          fallback_entry ? [fallback_entry] : []
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
        occurred_at: parse_time(attempt['finished_at']) || parse_time(attempt['started_at']) || supplier_import.finished_at || supplier_import.created_at,
        result_code: attempt['result'].presence || record['business_status'].presence || record['final_status'].presence,
        observation: attempt['observation'].presence || record['observation'].presence,
        customer_transcript: attempt['customer_transcript'].presence || record['customer_transcript'].presence,
        assistant_transcript: attempt['assistant_transcript'].presence || record['assistant_transcript'].presence,
        summary: attempt['transcript_summary'].presence || record['transcript_summary'].presence || record['observation'].presence,
        provider_call_id: attempt['provider_call_id'],
        attempt_number: attempt['attempt_number'],
        record_external_id: record['external_id']
      )
    end

    def build_record_entry(supplier_import, record)
      return if [
        record['customer_transcript'],
        record['assistant_transcript'],
        record['transcript_summary'],
        record['observation']
      ].all?(&:blank?)

      Entry.new(
        lot_code: supplier_import.display_code,
        lot_id: supplier_import.id,
        supplier_name: supplier_name_for(record),
        workflow_kind: supplier_import.workflow_kind,
        source: supplier_import.source,
        occurred_at: parse_time(record['finished_at']) || supplier_import.finished_at || supplier_import.created_at,
        result_code: record['call_result'].presence || record['business_status'].presence || record['final_status'].presence,
        observation: record['observation'].presence,
        customer_transcript: record['customer_transcript'],
        assistant_transcript: record['assistant_transcript'],
        summary: record['transcript_summary'].presence || record['observation'].presence,
        provider_call_id: nil,
        attempt_number: nil,
        record_external_id: record['external_id']
      )
    end

    def supplier_name_for(record)
      record['client_name'].presence || record['company_name'].presence || record['external_id'].presence || 'Registro'
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
