class AddLastStripeEventTsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_stripe_event_ts, :integer
  end
end
