module Spreadsheets
  module CellSanitizer
    DANGEROUS_PREFIX = /\A[=+\-@\t\r]/
    SIGNED_NUMBER = /\A[+-]\d+(?:[.,]\d+)?\z/

    module_function

    def sanitize(value)
      return value unless value.is_a?(String)
      return value if value.match?(SIGNED_NUMBER)
      return value unless value.match?(DANGEROUS_PREFIX)

      "'#{value}"
    end
  end
end
