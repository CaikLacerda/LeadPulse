class SyncSupplierImportStatusesJob < ApplicationJob
  queue_as :default

  def perform
    SupplierImports::SyncAllRemoteStatusesService.new.call
  end
end
