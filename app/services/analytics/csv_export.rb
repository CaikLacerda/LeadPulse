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

    RECORD_COLUMNS = RowPresenter::RECORD_FIELDS
    ATTEMPT_COLUMNS = RowPresenter::ATTEMPT_FIELDS
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
      rows.each do |row|
        presented = dataset == "registros" ? RowPresenter.record(row) : RowPresenter.attempt(row)
        yield CSV.generate_line(columns.map { |column| format_value(column, presented) })
      end
    end

    private

    def rows
      if dataset == "registros"
        RecordsQuery.new(@scope.validated_batches(@filters.window)).each_row
      else
        AttemptsQuery.new(@scope.attempt_batches(@filters.window), @filters.window).each_row
      end
    end

    # Mesmos campos da API de BI; no CSV, texto é protegido contra fórmulas de planilha.
    def format_value(column, row)
      value = row.fetch(column)
      TEXT_COLUMNS.include?(column) && value.is_a?(String) ? Spreadsheets::CellSanitizer.sanitize(value) : value
    end
  end
end
