class AddFormStatusToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :form_status, :integer, null: false, default: 0
  end
end
