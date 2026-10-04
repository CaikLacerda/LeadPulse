module SimulationsHelper
  # Tom e ícone do selo de cada status da execução. Espelhado em simulation_live_controller.js.
  SIMULATION_STATUS_BADGES = {
    "queued" => [ :warning, "fa-clock" ],
    "running" => [ :info, nil ],
    "completed" => [ :success, nil ],
    "failed" => [ :danger, nil ],
    "cancelled" => [ :neutral, nil ],
    "interrupted" => [ :warning, nil ]
  }.freeze

  def simulation_status_badge(status)
    tone, icon = SIMULATION_STATUS_BADGES.fetch(status.to_s, [ :neutral, nil ])
    status_badge(t("simulations.statuses.#{status}", default: status.to_s.humanize), tone: tone, icon: icon, pulse: status.to_s == "running")
  end

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
