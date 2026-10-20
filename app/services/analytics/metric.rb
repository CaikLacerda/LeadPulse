module Analytics
  # Valor de um indicador junto com a amostra (n) que o sustenta. O limite de amostra é só de
  # apresentação: abaixo dele a tela mostra "Baixa amostra" e não trata a variação como
  # conclusiva. Nenhuma métrica é escondida por ter amostra pequena.
  Metric = Data.define(:kind, :value, :sample, :numerator) do
    const_set(:MIN_SAMPLE, 20)

    def self.count(value)
      new(kind: :count, value: value.to_i, sample: value.to_i, numerator: nil)
    end

    # Taxa como fração (0.625 = 62,5%). Sem denominador, o valor fica nil e não vira 0%.
    def self.rate(numerator, denominator)
      denominator = denominator.to_i
      value = denominator.positive? ? numerator.to_f / denominator : nil
      new(kind: :rate, value: value, sample: denominator, numerator: numerator.to_i)
    end

    def self.duration(seconds, sample)
      new(kind: :duration, value: seconds&.to_f, sample: sample.to_i, numerator: nil)
    end

    def self.average(total, sample)
      sample = sample.to_i
      new(kind: :average, value: sample.positive? ? total.to_f / sample : nil, sample: sample, numerator: nil)
    end

    def low_sample?
      sample < self.class::MIN_SAMPLE
    end

    def available?
      !value.nil?
    end
  end
end
