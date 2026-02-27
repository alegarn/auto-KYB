require 'rails_helper'

RSpec.describe CrmTransfer, type: :model do
  describe 'associations' do
    it 'belongs to client and crm_connection' do
      client = create(:client)
      conn = create(:crm_connection)
      transfer = create(:crm_transfer, client: client, crm_connection: conn)

      expect(transfer.client).to eq(client)
      expect(transfer.crm_connection).to eq(conn)
    end
  end
end
