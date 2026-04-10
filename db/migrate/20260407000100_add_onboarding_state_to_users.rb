class AddOnboardingStateToUsers < ActiveRecord::Migration[8.1]

  def change
    add_column :users, :onboarding_state, :jsonb, default: {}, null: false
  end

end