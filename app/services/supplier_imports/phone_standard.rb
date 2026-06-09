module SupplierImports
  module PhoneStandard
    module_function

    LABEL = 'E.164, no formato +55DDDNÚMERO'.freeze

    def e164(value)
      normalized = SupplierImports::ValueNormalizer.identifier(value)
      return normalized if normalized.blank?
      return normalized if normalized.start_with?('+')

      digits = normalized.gsub(/\D/, '')
      return normalized if digits.blank?
      return "+#{digits}" if digits.start_with?('55') && [12, 13].include?(digits.length)
      return "+55#{digits}" if [10, 11].include?(digits.length)

      normalized
    end
  end
end
