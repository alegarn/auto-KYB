class CreateClientInvitationEmailSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :client_invitation_email_settings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.boolean :auto_send, null: false, default: false
      t.text :subject_template
      t.text :body_template
      t.timestamps
    end
  end
end
