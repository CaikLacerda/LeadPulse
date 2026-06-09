class Plan < ApplicationRecord
  self.inheritance_column = :_type_disabled

  validates :type, presence: true
  validates :usage, numericality: { greater_than_or_equal_to: 0 }
  validates :value, numericality: { greater_than_or_equal_to: 0 }
  validates :supplier_limit, presence: true
end
