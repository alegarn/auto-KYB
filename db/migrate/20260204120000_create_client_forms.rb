class CreateClientForms < ActiveRecord::Migration[8.1]
  def change
    create_table :client_forms, id: :uuid do |t|
      t.uuid :client_id, null: false
      t.uuid :form_id, null: false
      t.integer :status, null: false, default: 0
      t.string :password_digest
      t.string :access_token
      t.datetime :expires_at
      t.datetime :validated_at
      t.timestamps
    end

    add_index :client_forms, :client_id
    add_index :client_forms, :form_id
    add_index :client_forms, :access_token, unique: true
    add_foreign_key :client_forms, :clients, column: :client_id
    add_foreign_key :client_forms, :forms, column: :form_id
  end
end
