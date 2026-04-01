class CreateCrmConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :crm_connections, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :provider
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at
      t.string :status

      t.timestamps
    end
  end
end
