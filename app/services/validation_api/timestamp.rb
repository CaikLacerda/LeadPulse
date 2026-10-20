module ValidationApi
  # A API de validação grava horários em UTC, mas nem sempre envia o sufixo de fuso
  # ("2026-07-21T17:34:15.088290"). Sem o sufixo, Time.zone.parse leria o valor no fuso da
  # aplicação (America/Sao_Paulo) e o deslocaria em 3 horas. Valores com fuso explícito são
  # respeitados como vieram.
  module Timestamp
    module_function

    def parse(value)
      return if value.blank?
      return value.in_time_zone if value.respond_to?(:in_time_zone) && !value.is_a?(String)

      raw = value.to_s.strip
      zone = Date._parse(raw).key?(:offset) ? Time.zone : Time.find_zone!("UTC")
      zone.parse(raw)&.in_time_zone
    rescue ArgumentError, TypeError
      nil
    end
  end
end
