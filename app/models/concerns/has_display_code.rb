module HasDisplayCode
  extend ActiveSupport::Concern

  included do
    class_attribute :display_code_prefix_value, instance_writer: false
  end

  class_methods do
    def display_code_prefix(value)
      self.display_code_prefix_value = value
    end

    # Código exibido a partir do id, para listas que não carregam o registro (ex.: Analytics).
    def display_code_for(id)
      prefix = display_code_prefix_value
      raise NotImplementedError, "#{name} deve definir display_code_prefix." if prefix.blank?

      "#{prefix}-#{id.to_s.rjust(3, '0')}"
    end
  end

  def display_number
    id.to_s.rjust(3, "0")
  end

  def display_code
    self.class.display_code_for(id)
  end
end
