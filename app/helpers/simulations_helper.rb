module SimulationsHelper
  # Duração em ms (da API) formatada como m:ss, ou traço quando ausente.
  def simulation_duration(duration_ms)
    return "—" if duration_ms.blank?

    total_seconds = (duration_ms.to_i / 1000.0).round
    minutes, seconds = total_seconds.divmod(60)
    format("%d:%02d", minutes, seconds)
  end

  # Apresenta um valor esperado/coletado da avaliação de forma legível, sem inventar texto:
  # booleanos viram Sim/Não, nulos viram traço, o resto é o próprio valor.
  def simulation_field_value(value)
    case value
    when true then t("simulations.values.yes")
    when false then t("simulations.values.no")
    when nil, "" then "—"
    else value.to_s
    end
  end
end
