class AddAsyncFieldsToCrmTransfers < ActiveRecord::Migration[8.1]
  def up
    add_column :crm_transfers, :trigger, :string
    add_column :crm_transfers, :failure_kind, :string
    add_column :crm_transfers, :attempts_count, :integer, default: 0, null: false
    add_column :crm_transfers, :last_attempt_at, :datetime
    add_column :crm_transfers, :request_context, :jsonb, default: {}, null: false

    add_index :crm_transfers, :status
    add_index :crm_transfers, :trigger
    add_index :crm_transfers, :failure_kind

    change_column_default :crm_transfers, :status, from: nil, to: "pending"

    execute <<~SQL
      UPDATE crm_transfers
      SET
        status = COALESCE(status, 'pending'),
        trigger = CASE
          WHEN direction = 'import' THEN 'data_import'
          ELSE 'manual_export'
        END,
        attempts_count = COALESCE(attempts_count, 0),
        request_context = COALESCE(request_context, '{}'::jsonb)
    SQL

    change_column_null :crm_transfers, :trigger, false
  end

  def down
    change_column_null :crm_transfers, :trigger, true
    change_column_default :crm_transfers, :status, from: "pending", to: nil

    remove_index :crm_transfers, :failure_kind
    remove_index :crm_transfers, :trigger
    remove_index :crm_transfers, :status

    remove_column :crm_transfers, :request_context
    remove_column :crm_transfers, :last_attempt_at
    remove_column :crm_transfers, :attempts_count
    remove_column :crm_transfers, :failure_kind
    remove_column :crm_transfers, :trigger
  end
end