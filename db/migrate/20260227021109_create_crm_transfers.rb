class CreateCrmTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :crm_transfers, id: :uuid do |t|
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.references :crm_connection, null: false, foreign_key: true, type: :uuid
      t.string :status
      t.text :error_message
      t.datetime :transferred_at

      t.timestamps
    end
  end
end
