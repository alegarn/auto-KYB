class AddExternalIdsToCrmTransfers < ActiveRecord::Migration[8.0]
  def change
    add_column :crm_transfers, :external_id, :string         # HubSpot record ID
    add_column :crm_transfers, :external_type, :string        # "contact", "company", "file"
    add_column :crm_transfers, :direction, :string, default: "export"  # "export" or "import"
    add_column :crm_transfers, :payload_snapshot, :jsonb, default: {}  # what was sent (for audit)
  end
end
