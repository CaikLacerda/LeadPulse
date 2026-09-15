module SupplierImports
  module PhoneStandard
    module_function

    LABEL = "E.164, no formato +55DDDNÚMERO".freeze

    def e164(value)
      normalized = SupplierImports::ValueNormalizer.identifier(value)
      return normalized if normalized.blank?
      return normalized if normalized.start_with?("+")

      digits = normalized.gsub(/\D/, "")
      return normalized if digits.blank?
      return "+#{digits}" if digits.start_with?("55") && [ 12, 13 ].include?(digits.length)
      return "+55#{digits}" if [ 10, 11 ].include?(digits.length)

      normalized
    end

    def callback_e164(value)
      normalized = SupplierImports::ValueNormalizer.identifier(value)
      return normalized if normalized.blank?

      digits = normalized.gsub(/\D/, "")
      return normalized if digits.blank?

      if normalized.start_with?("00")
        international_digits = digits.delete_prefix("00")
        return "+#{international_digits}" if valid_international_digits?(international_digits)
      end

      return "+#{digits}" if normalized.start_with?("+") && valid_international_digits?(digits)
      return e164(normalized) if valid_brazilian_number?(digits)
      return "+#{digits}" if valid_international_digits?(digits)

      normalized
    end

    def valid_brazilian_number?(value)
      digits = value.to_s.gsub(/\D/, "")
      national_number =
        if digits.start_with?("55") && [ 12, 13 ].include?(digits.length)
          digits.delete_prefix("55")
        else
          digits
        end
      return false unless [ 10, 11 ].include?(national_number.length)

      ddd = national_number.first(2).to_i
      local_number = national_number.last(national_number.length - 2)
      return false unless ddd.between?(11, 99)

      (local_number.length == 9 && local_number.start_with?("9")) ||
        (local_number.length == 8 && %w[2 3 4 5].include?(local_number.first))
    end

    def valid_international_digits?(digits)
      digits.length.between?(8, 15) && !digits.start_with?("0")
    end
  end
end
