class AddHubspotFieldsToCrmConnections < ActiveRecord::Migration[8.0]
  def change
    add_column :crm_connections, :hub_id, :string          # HubSpot portal/account ID
    add_column :crm_connections, :scopes, :text             # granted scopes (space-separated)
    add_column :crm_connections, :token_type, :string        # "bearer"
    add_column :crm_connections, :metadata, :jsonb, default: {} # provider-specific extras

    # Safety constraint: Clean up potential dummy dupes before adding unique index
    reversible do |dir|
      dir.up do
        execute <<-SQL
          DELETE FROM crm_connections
          WHERE id IN (
            SELECT id FROM (
              SELECT id, ROW_NUMBER() OVER(PARTITION BY user_id, provider ORDER BY updated_at DESC) as row_num
              FROM crm_connections
            ) t WHERE t.row_num > 1
          )
        SQL
      end
    end

    add_index :crm_connections, [:user_id, :provider], unique: true,
              name: "index_crm_connections_on_user_provider"
  end
end
