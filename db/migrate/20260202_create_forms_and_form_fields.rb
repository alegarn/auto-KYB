class CreateFormsAndFormFields < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :forms, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :structure, default: {}
      t.timestamps
    end

    add_index :forms, :user_id

    create_table :form_fields, id: :uuid do |t|
      t.references :form, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :required, default: false, null: false
      t.integer :position
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :form_fields, :form_id
  end
end
