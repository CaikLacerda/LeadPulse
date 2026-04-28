module HasDisplayCode
  extend ActiveSupport::Concern

  included do
    class_attribute :display_code_prefix_value, instance_writer: false
  end

  class_methods do
    def display_code_prefix(value)
      self.display_code_prefix_value = value
    end
  end

  def display_number
    id.to_s.rjust(3, "0")
  end

  def display_code
    prefix = self.class.display_code_prefix_value
    raise NotImplementedError, "#{self.class.name} deve definir display_code_prefix." if prefix.blank?

    "#{prefix}-#{display_number}"
  end
end
