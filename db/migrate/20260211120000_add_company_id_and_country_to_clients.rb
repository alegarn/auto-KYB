class AddCompanyIdAndCountryToClients < ActiveRecord::Migration[7.0]
  def change
    add_column :clients, :company_id, :string
    add_column :clients, :country, :string

    add_index :clients, :company_id
    add_index :clients, :country
  end
end
