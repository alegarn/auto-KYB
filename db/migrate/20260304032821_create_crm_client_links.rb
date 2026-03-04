class CreateCrmClientLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :crm_client_links, id: :uuid do |t|
      t.references :client, null: false, foreign_key: true, type: :uuid
      t.references :crm_connection, null: false, foreign_key: true, type: :uuid
      t.string :external_contact_id
      t.string :external_company_id

      t.timestamps
    end
  end
end
