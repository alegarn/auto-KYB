require 'rails_helper'

RSpec.describe ClientFormRemapperService do
  describe '.call' do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }
    let(:form_a) { create(:form, user: user) }
    let(:form_b) { create(:form, user: user) }

    context 'when client is inactive or has no responses' do
      it 'creates a new client_form invitation' do
        result = described_class.call(client: client, new_form: form_a, confirm_replace: false)

        expect(result[:status]).to eq(:created)
        expect(result[:client_form]).to be_present
        expect(result[:password]).to be_present
      end
    end

    context 'when client is active and has responses' do
      before do
        # create existing client_form and a response
        cf = ClientInvitationService.create_invitation(client: client, form: form_a)
        cf_id = cf[:client_form].id
        ClientForm.find(cf_id).save_response!(data: { a: 1 })
        client.reload
      end

      it 'raises ConfirmReplaceRequired when not confirmed' do
        expect {
          described_class.call(client: client, new_form: form_b, confirm_replace: false)
        }.to raise_error(ClientFormRemapperService::ConfirmReplaceRequired)
      end

      it 'replaces responses and creates new invitation when confirmed' do
        result = described_class.call(client: client, new_form: form_b, confirm_replace: true)

        expect(result[:status]).to eq(:created)
        expect(result[:client_form]).to be_present
        # old responses should be deleted
        expect(FormResponse.where(client_form_id: client.client_forms.where(form_id: form_a.id).pluck(:id)).count).to eq(0)
      end
    end
  end
end
