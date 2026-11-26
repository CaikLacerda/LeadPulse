module Analytics
  # Comparação entre a janela atual e a de comparação, calculada no backend.
  # status: :ok, :low_sample (não conclusiva), :no_base (sem base anterior) ou :unavailable.
  # delta: fração relativa para contagens, diferença de fração (p.p. ÷ 100) para taxas e
  # segundos para durações.
  Comparison = Data.define(:current, :previous) do
    def status
      return :unavailable if previous.nil? || !current.available?
      return :no_base if !previous.available? || (current.kind == :count && previous.value.zero?)
      return :low_sample if current.low_sample? || previous.low_sample?

      :ok
    end

    def conclusive?
      status == :ok
    end

    def delta
      return unless %i[ok low_sample].include?(status)

      case current.kind
      when :count then (current.value - previous.value) / previous.value.to_f
      else current.value - previous.value
      end
    end
  end
end
