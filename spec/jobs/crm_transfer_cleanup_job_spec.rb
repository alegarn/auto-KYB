require 'rails_helper'

RSpec.describe CrmTransferCleanupJob, type: :job do
  describe '#perform' do
    it 'deletes successful and failed transfers older than the retention cutoff' do
      old_success = create(:crm_transfer, :success, created_at: 4.days.ago)
      old_failed = create(:crm_transfer, :failed, created_at: 5.days.ago)
      recent_failed = create(:crm_transfer, :failed, created_at: 2.days.ago)

      expect { described_class.perform_now }.to change(CrmTransfer, :count).by(-2)

      expect(CrmTransfer.exists?(old_success.id)).to be(false)
      expect(CrmTransfer.exists?(old_failed.id)).to be(false)
      expect(CrmTransfer.exists?(recent_failed.id)).to be(true)
    end

    it 'keeps transfers that are still inside the three-day window' do
      recent_pending = create(:crm_transfer, created_at: 1.day.ago)
      boundary_transfer = create(:crm_transfer, created_at: 3.days.ago + 5.minutes)

      expect { described_class.perform_now }.not_to change(CrmTransfer, :count)

      expect(CrmTransfer.exists?(recent_pending.id)).to be(true)
      expect(CrmTransfer.exists?(boundary_transfer.id)).to be(true)
    end
  end
end