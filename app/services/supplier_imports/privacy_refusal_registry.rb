require "set"

module SupplierImports
  module PrivacyRefusalRegistry
    module_function

    def blocked_phone_numbers_for(user)
      user.supplier_imports.find_each.with_object(Set.new) do |supplier_import, numbers|
        Array(supplier_import.response_payload["records"]).each do |record|
          next unless privacy_refusal?(record)

          phone = record_phone(record)
          numbers << normalized_phone(phone) if phone.present?
        end
      end
    end

    def blocked?(phone, blocked_numbers)
      normalized = normalized_phone(phone)
      normalized.present? && blocked_numbers.include?(normalized)
    end

    def normalized_phone(phone)
      SupplierImports::PhoneStandard.e164(phone)
    rescue ArgumentError
      phone.to_s.gsub(/\D/, "")
    end

    def privacy_refusal?(record)
      record["privacy_refusal_detected"].present? ||
        Array(record["call_attempts"]).any? { |attempt| attempt["privacy_refusal_detected"].present? }
    end

    def record_phone(record)
      record["phone_normalized"].presence ||
        record["phone_original"].presence ||
        record["validated_phone"].presence ||
        record["last_phone_dialed"].presence ||
        record["phone"].presence ||
        record["phone_e164"].presence ||
        record["normalized_phone"].presence ||
        record["original_phone"].presence ||
        Array(record["call_attempts"]).filter_map do |attempt|
          attempt["phone_dialed"].presence || attempt["to_phone"].presence || attempt["phone"].presence
        end.first
    end
  end
end
