require 'rails_helper'

RSpec.describe ClientUpdateService, type: :service do
  describe '.call' do
    let(:user) { create(:user) }
    let(:client) { create(:client, user: user) }

    context 'when params are valid and no new_form' do
      it 'updates the client and returns a success result' do
        result = described_class.call(client: client, client_params: { name: 'Updated Name' })

        expect(result).to be_success
        expect(result.action).to eq(:success)
        expect(client.reload.name).to eq('Updated Name')
      end
    end

    context 'when params are invalid' do
      it 'raises ActiveRecord::RecordInvalid and does not update the client' do
        original_name = client.name

        expect {
          described_class.call(client: client, client_params: { name: nil, company_name: nil })
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(client.reload.name).to eq(original_name)
      end
    end

    context 'when new_form is given and no existing responses' do
      it 'returns :password_reveal result and creates client_form invitation' do
        form = create(:form, user: user)
        client_form = double('ClientForm', id: 99)

        allow(ClientFormRemapperService).to receive(:call).and_return({
          status: :created,
          client_form: client_form,
          password: 'secret123'
        })

        result = described_class.call(client: client, client_params: { name: client.name }, new_form: form)

        expect(result).to be_password_reveal
        expect(result.password).to eq('secret123')
      end
    end

    context 'when confirm_replace is required' do
      it 'returns :confirm_replace result and rolls back the client update' do
        form = create(:form, user: user)
        original_name = client.name

        allow(ClientFormRemapperService).to receive(:call)
          .and_raise(ClientFormRemapperService::ConfirmReplaceRequired.new(form.id))

        result = described_class.call(
          client: client,
          client_params: { name: 'Attempted Name' },
          new_form: form,
          confirm_replace: false
        )

        expect(result).to be_confirm_replace
        expect(result.attempted_form_id).to eq(form.id)
        expect(client.reload.name).to eq(original_name)
      end
    end

    context 'when new_form remapping succeeds with existing form (no new invitation)' do
      it 'returns success when ClientFormRemapperService returns non-:created status' do
        form = create(:form, user: user)

        allow(ClientFormRemapperService).to receive(:call).and_return({ status: :existing })

        result = described_class.call(client: client, client_params: { name: 'New Name' }, new_form: form)

        expect(result).to be_success
        expect(client.reload.name).to eq('New Name')
      end
    end
  end
end
