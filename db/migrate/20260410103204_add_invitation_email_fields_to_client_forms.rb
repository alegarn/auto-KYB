class AddInvitationEmailFieldsToClientForms < ActiveRecord::Migration[8.1]
  def change
    add_column :client_forms, :invitation_emailed_at, :datetime
    add_column :client_forms, :invitation_emailed_to, :string
  end
end
