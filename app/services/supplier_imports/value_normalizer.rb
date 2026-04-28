module SupplierImports
  module ValueNormalizer
    module_function

    def text(value)
      return nil if value.nil?

      string = value.to_s.strip
      string.presence
    end

    def identifier(value)
      return nil if value.nil?

      normalized = if value.is_a?(Numeric)
        integer_value = value.to_i
        if value.to_f == integer_value.to_f
          integer_value.to_s
        else
          value.to_s
        end
      else
        value.to_s.strip
      end

      normalized = normalized.sub(/\A([-+]?\d+)\.0+\z/, '\1')
      normalized = normalized.sub(/\A([-+]?\d+),0+\z/, '\1')
      normalized.presence
    end
  end
end
