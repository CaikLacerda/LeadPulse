class ApplyLgpdRetentionJob < ApplicationJob
  queue_as :default

  def perform
    SupplierImports::ApplyRetentionService.new.call
  end
end
