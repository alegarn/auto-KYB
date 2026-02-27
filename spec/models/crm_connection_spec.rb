require 'rails_helper'

RSpec.describe CrmConnection, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      user = create(:user)
      conn = create(:crm_connection, user: user)
      expect(conn.user).to eq(user)
    end

    it 'has many crm_transfers' do
      conn = create(:crm_connection)
      transfer = create(:crm_transfer, crm_connection: conn)
      expect(conn.crm_transfers).to include(transfer)
    end
  end
end
