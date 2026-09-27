require "csv"

module Analytics
  # CSV bruto para integração, gerado linha a linha (streaming). As colunas são um contrato
  # estável: nomes em inglês, códigos da API em vez de rótulos, datas ISO 8601 em UTC,
  # durações em segundos inteiros e célula vazia quando não há valor. UTF-8 com BOM para o
  # Excel em pt-BR abrir os acentos. Nunca inclui telefone, e-mail, transcrição nem gravação.
  class CsvExport
    CONTENT_TYPE = "text/csv; charset=utf-8".freeze
    BOM = "﻿".freeze
    DATASETS = %w[registros chamadas].freeze

    RECORD_COLUMNS = %w[
      batch_code workflow_kind source batch_status validation_started_at record_external_id
      company_name cnpj segment_name final_status call_result call_status business_status
      qualification_outcome phone_belongs_to_company supplies_segment commercial_interest
      attempts_count privacy_refusal_detected last_attempt_at answered_duration_seconds
    ].freeze

    ATTEMPT_COLUMNS = %w[
      batch_code workflow_kind source record_external_id attempt_number started_at finished_at
      status result duration_seconds privacy_refusal_detected
    ].freeze

    TEXT_COLUMNS = %w[record_external_id company_name cnpj segment_name].freeze

    attr_reader :dataset

    def initialize(scope:, dataset:, generated_at: Time.current)
      raise ArgumentError, "Conjunto de dados desconhecido: #{dataset}" unless DATASETS.include?(dataset)

      @scope = scope
      @filters = scope.filters
      @dataset = dataset
      @generated_at = generated_at.in_time_zone(Sql::TIME_ZONE)
    end

    def filename
      "leadpulse_analytics_#{dataset}_#{@generated_at.to_date.iso8601}.csv"
    end

    def columns
      dataset == "registros" ? RECORD_COLUMNS : ATTEMPT_COLUMNS
    end

    # Enumerator de linhas: o controller entrega direto como corpo da resposta.
    def each
      return enum_for(:each) unless block_given?

      yield BOM + CSV.generate_line(columns)
      rows.each { |row| yield CSV.generate_line(columns.map { |column| format_value(column, row) }) }
    end

    private

    def rows
      if dataset == "registros"
        RecordsQuery.new(@scope.validated_batches(@filters.window)).each_row
      else
        AttemptsQuery.new(@scope.attempt_batches(@filters.window), @filters.window).each_row
      end
    end

    def format_value(column, row)
      value = column == "batch_code" ? SupplierImport.display_code_for(row[:batch_id]) : row[column_key(column)]

      case value
      when nil then nil
      when true, false then value.to_s
      when Time, ActiveSupport::TimeWithZone then value.utc.iso8601
      when Float then column.end_with?("_seconds") ? value.round : value
      else TEXT_COLUMNS.include?(column) ? Spreadsheets::CellSanitizer.sanitize(value.to_s) : value
      end
    end

    def column_key(column)
      { "record_external_id" => :external_id }.fetch(column, column.to_sym)
    end
  end
end
