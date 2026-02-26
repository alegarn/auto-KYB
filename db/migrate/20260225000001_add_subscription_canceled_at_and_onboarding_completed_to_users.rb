class AddSubscriptionCanceledAtAndOnboardingCompletedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :subscription_canceled_at, :datetime
    add_column :users, :onboarding_completed, :boolean, null: false, default: false
    add_index  :users, :subscription_canceled_at
  end
end
