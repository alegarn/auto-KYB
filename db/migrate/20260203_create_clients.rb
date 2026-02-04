class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.string :name, null: false
      t.string :company_name, null: false
      t.string :email
      t.string :phone
      t.jsonb :address
      t.timestamps
    end

    add_index :clients, :user_id
    add_foreign_key :clients, :users, column: :user_id

    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE INDEX index_clients_on_user_id_and_lower_name ON clients (user_id, lower(name));
          CREATE INDEX index_clients_on_user_id_and_lower_company_name ON clients (user_id, lower(company_name));
        SQL
      end
      dir.down do
        execute <<-SQL
          DROP INDEX IF EXISTS index_clients_on_user_id_and_lower_name;
          DROP INDEX IF EXISTS index_clients_on_user_id_and_lower_company_name;
        SQL
      end
    end
  end
end
