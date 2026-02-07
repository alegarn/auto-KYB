class CreateFormResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :form_responses, id: :uuid do |t|
      t.uuid :client_form_id, null: false
      t.jsonb :data, default: {}
      t.integer :version, null: false, default: 1
      t.timestamps
    end

    add_index :form_responses, :client_form_id
    add_index :form_responses, [:client_form_id, :version], unique: true
    add_foreign_key :form_responses, :client_forms, column: :client_form_id
  end
end
