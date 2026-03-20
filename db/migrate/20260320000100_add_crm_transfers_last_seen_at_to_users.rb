class AddCrmTransfersLastSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :crm_transfers_last_seen_at, :datetime
  end
end