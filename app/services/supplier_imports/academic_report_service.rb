module SupplierImports
  class AcademicReportService
    CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
    DISPLAY_TIME_ZONE = 'America/Sao_Paulo'.freeze

    POSITIVE_RESULTS = %w[
      confirmed_by_call
      confirmed_by_whatsapp
      confirmed_by_email
      confirmed
      validated
      qualified_supplier
    ].freeze

    NEGATIVE_RESULTS = %w[
      wrong_company
      does_not_supply_segment
      not_interested
      privacy_refusal
      rejected
      invalid_phone
      validation_failed
      failed
    ].freeze

    INCONCLUSIVE_RESULTS = %w[inconclusive inconclusive_call].freeze
    NOT_ANSWERED_RESULTS = %w[not_answered busy].freeze

    def initialize(imports:)
      @imports = imports
    end

    def call
      imports = @imports.to_a
      metrics = build_metrics(imports)
      rows = build_rows(imports, metrics)

      {
        filename: "relatorio-validacao-#{Time.current.strftime('%Y%m%d%H%M')}.xlsx",
        content: Spreadsheets::SimpleXlsxBuilder.new(sheet_name: 'Indicadores', rows: rows).call,
        content_type: CONTENT_TYPE
      }
    end

    private

    def build_rows(imports, metrics)
      [
        ['Relatório de validação LeadPulse', ''],
        ['Gerado em', Time.current.in_time_zone(DISPLAY_TIME_ZONE).strftime('%d/%m/%Y %H:%M')],
        [],
        ['Indicador', 'Valor'],
        ['Lotes analisados', metrics[:imports_count]],
        ['Registros importados', metrics[:total_rows]],
        ['Registros com retorno da API', metrics[:returned_records]],
        ['Cobertura do processamento', percent(metrics[:coverage])],
        ['Taxa de confirmação', percent(metrics[:confirmation_rate])],
        ['Taxa de retrabalho', percent(metrics[:rework_rate])],
        ['Tempo médio de chamada', seconds(metrics[:average_call_duration])],
        ['Tempo médio manual', seconds(metrics[:average_manual_duration])],
        ['Redução estimada de tempo', percent(metrics[:time_reduction_rate])],
        ['Acurácia com base rotulada', percent(metrics[:accuracy])],
        ['Registros rotulados usados na acurácia', metrics[:labeled_records]],
        ['Confirmados', metrics[:confirmed_records]],
        ['Não confirmados', metrics[:negative_records]],
        ['Inconclusivos', metrics[:inconclusive_records]],
        ['Não atendidos', metrics[:not_answered_records]],
        [],
        ['Por lote', '', '', '', '', '', ''],
        ['Lote', 'Tipo', 'Status', 'Total', 'Retornados', 'Confirmados', 'Tempo médio']
      ] + imports.map { |supplier_import| lot_row(supplier_import) }
    end

    def build_metrics(imports)
      all_records = imports.flat_map { |supplier_import| response_records(supplier_import) }
      returned_records = all_records.size
      total_rows = imports.sum(&:total_rows)
      attempts = all_records.flat_map { |record| Array(record['call_attempts']) }
      durations = attempts.filter_map { |attempt| duration_seconds(attempt) }
      labels = labeled_comparisons(imports)
      manual_durations = manual_duration_values(imports)
      average_call_duration = average(durations)
      average_manual_duration = average(manual_durations)

      {
        imports_count: imports.size,
        total_rows: total_rows,
        returned_records: returned_records,
        coverage: ratio(returned_records, total_rows),
        confirmed_records: all_records.count { |record| positive_result?(result_code(record)) },
        negative_records: all_records.count { |record| negative_result?(result_code(record)) },
        inconclusive_records: all_records.count { |record| INCONCLUSIVE_RESULTS.include?(result_code(record)) },
        not_answered_records: all_records.count { |record| NOT_ANSWERED_RESULTS.include?(result_code(record)) },
        confirmation_rate: ratio(all_records.count { |record| positive_result?(result_code(record)) }, returned_records),
        rework_rate: ratio(all_records.count { |record| Array(record['call_attempts']).size > 1 }, returned_records),
        average_call_duration: average_call_duration,
        average_manual_duration: average_manual_duration,
        time_reduction_rate: time_reduction_rate(average_manual_duration, average_call_duration),
        accuracy: labels.empty? ? nil : ratio(labels.count { |comparison| comparison[:expected] == comparison[:actual] }, labels.size),
        labeled_records: labels.size
      }
    end

    def lot_row(supplier_import)
      records = response_records(supplier_import)
      attempts = records.flat_map { |record| Array(record['call_attempts']) }
      durations = attempts.filter_map { |attempt| duration_seconds(attempt) }

      [
        supplier_import.display_code,
        supplier_import.workflow_kind_label,
        supplier_import.status,
        supplier_import.total_rows,
        records.size,
        records.count { |record| positive_result?(result_code(record)) },
        seconds(average(durations))
      ]
    end

    def labeled_comparisons(imports)
      imports.flat_map do |supplier_import|
        labels = Array(supplier_import.import_metadata['reference_labels']).index_by { |label| label['external_id'].to_s }

        response_records(supplier_import).filter_map do |record|
          expected = labels.dig(record['external_id'].to_s, 'expected_result')
          next if expected.blank?

          {
            expected: normalize_expected_result(expected),
            actual: result_code(record)
          }
        end
      end
    end

    def manual_duration_values(imports)
      imports.flat_map do |supplier_import|
        Array(supplier_import.import_metadata['reference_labels']).filter_map do |label|
          value = label['manual_validation_seconds'].presence
          value.to_f if value.present?
        end
      end
    end

    def response_records(supplier_import)
      Array(supplier_import.response_payload['records'])
    end

    def result_code(record)
      return 'privacy_refusal' if record['privacy_refusal_detected'].present?

      raw = record['supplier_validation'].is_a?(Hash) ? record['supplier_validation']['outcome'].presence : nil
      raw ||= record['business_status'].presence
      raw ||= record['final_status'].presence
      raw ||= record['call_result'].presence
      normalize_expected_result(raw)
    end

    def normalize_expected_result(value)
      normalized = ActiveSupport::Inflector.transliterate(value.to_s).strip.downcase.tr(' ', '_').tr('-', '_')
      {
        'confirmada' => 'confirmed_by_call',
        'confirmado' => 'confirmed_by_call',
        'validada' => 'validated',
        'validado' => 'validated',
        'fornecedor_qualificado' => 'qualified_supplier',
        'numero_nao_pertence_a_empresa' => 'wrong_company',
        'nao_pertence_a_empresa' => 'wrong_company',
        'nao_fornece_o_segmento' => 'does_not_supply_segment',
        'sem_interesse_comercial' => 'not_interested',
        'recusa_lgpd' => 'privacy_refusal',
        'recusa_privacidade' => 'privacy_refusal',
        'nao_atendida' => 'not_answered',
        'inconclusiva' => 'inconclusive'
      }.fetch(normalized, normalized)
    end

    def positive_result?(code)
      POSITIVE_RESULTS.include?(code)
    end

    def negative_result?(code)
      NEGATIVE_RESULTS.include?(code)
    end

    def duration_seconds(attempt)
      value = attempt['duration_seconds'].presence || attempt['call_duration_seconds'].presence
      return value.to_f if value.present?

      started_at = parse_time(attempt['started_at'])
      finished_at = parse_time(attempt['finished_at'])
      return if started_at.blank? || finished_at.blank?

      finished_at - started_at
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def average(values)
      return nil if values.blank?

      values.sum.to_f / values.size
    end

    def time_reduction_rate(manual_average, automated_average)
      return nil if manual_average.blank? || manual_average.to_f <= 0 || automated_average.blank?

      (manual_average.to_f - automated_average.to_f) / manual_average.to_f
    end

    def ratio(numerator, denominator)
      return nil if denominator.to_i.zero?

      numerator.to_f / denominator.to_f
    end

    def percent(value)
      return 'N/D' if value.nil?

      "#{(value * 100).round(2)}%"
    end

    def seconds(value)
      return 'N/D' if value.nil?

      "#{value.round(1)} s"
    end
  end
end
