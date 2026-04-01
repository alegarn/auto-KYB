class CrmTransferCleanupJob < ApplicationJob
  queue_as :default

  def perform
    CrmTransfer.older_than_retention_cutoff.delete_all
  end
end