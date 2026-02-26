class AddStripeFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :stripe_customer_id, :string
    add_index  :users, :stripe_customer_id

    add_column :users, :stripe_subscription_id, :string
    add_index  :users, :stripe_subscription_id

    add_column :users, :subscription_status, :string, null: false, default: "incomplete"

    add_column :users, :subscription_ends_at, :datetime
  end
end
