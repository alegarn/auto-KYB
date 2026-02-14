class CreateUploadedFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :uploaded_files, id: :uuid, default: -> { "gen_random_uuid()" }, if_not_exists: true do |t|
      t.uuid     :form_response_id
      t.uuid     :client_id,              null: false
      t.string   :field_key,              null: false
      t.string   :status,                 null: false, default: "available"
      t.datetime :uploaded_at,            null: false, default: -> { "now()" }
      t.datetime :downloaded_at
      t.datetime :deleted_at
      t.uuid     :downloaded_by_user_id
      t.jsonb    :metadata,               null: false, default: {}

      t.timestamps
    end

    add_index :uploaded_files, :form_response_id
    add_index :uploaded_files, :client_id
    add_index :uploaded_files, [:form_response_id, :field_key], name: "index_uploaded_files_on_response_and_field"
    add_index :uploaded_files, :deleted_at

    add_foreign_key :uploaded_files, :form_responses, on_delete: :nullify
    add_foreign_key :uploaded_files, :clients, on_delete: :cascade
    add_foreign_key :uploaded_files, :users, column: :downloaded_by_user_id, on_delete: :nullify
  end
end
