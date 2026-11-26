module Analytics
  # Fragmentos SQL das queries sobre o response_payload (JSONB). Os valores vêm da API externa
  # e podem vir incompletos: todo cast é protegido por regex e vira NULL em vez de falhar.
  module Sql
    TIME_ZONE = "America/Sao_Paulo".freeze
    NAIVE_TIMESTAMP = '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?$'.freeze
    ZONED_TIMESTAMP = '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}(:?\d{2})?)$'.freeze
    NUMBER = '^\d+(\.\d+)?$'.freeze

    module_function

    # Mesma regra de ValidationApi::Timestamp: horário sem fuso é UTC. Devolve timestamptz.
    def timestamp(text)
      "(CASE WHEN #{text} ~ '#{NAIVE_TIMESTAMP}' THEN (#{text})::timestamp AT TIME ZONE 'UTC' " \
        "WHEN #{text} ~* '#{ZONED_TIMESTAMP}' THEN (#{text})::timestamptz END)"
    end

    # Coluna datetime do Rails (timestamp sem fuso, gravado em UTC) como timestamptz.
    def column_time(column)
      "(#{column} AT TIME ZONE 'UTC')"
    end

    # Horário local de Brasília de um timestamptz, sem fuso.
    def local(timestamptz)
      "timezone('#{TIME_ZONE}', #{timestamptz})"
    end

    # Dia (ou segunda-feira da semana) local de um timestamptz.
    def bucket(timestamptz, grouping)
      local_time = local(timestamptz)
      case grouping
      when Filters::GROUPING_WEEK then "date_trunc('week', #{local_time})::date"
      when Filters::GROUPING_MONTH then "date_trunc('month', #{local_time})::date"
      else "(#{local_time})::date"
      end
    end

    def number(text)
      "(CASE WHEN #{text} ~ '#{NUMBER}' THEN (#{text})::numeric END)"
    end

    def array(jsonb)
      "(CASE WHEN jsonb_typeof(#{jsonb}) = 'array' THEN #{jsonb} ELSE '[]'::jsonb END)"
    end

    def list(values)
      values.map { |value| ActiveRecord::Base.connection.quote(value) }.join(", ")
    end
  end
end
