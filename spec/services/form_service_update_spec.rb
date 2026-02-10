require 'rails_helper'

RSpec.describe FormService, type: :service do
  let(:user) { FactoryBot.create(:user) }

  describe '.update_form data-loss warning' do
    it 'raises a warning when fields removed may cause data loss' do
      form = FormService.create_form(user, { name: 'WithData', structure: { fields: [ { label: 'Keep', field_type: 'text' }, { label: 'Remove', field_type: 'text' } ] } })
      # Simulate a submission stored elsewhere that references the 'Remove' field by label
      allow(Form).to receive(:has_submissions_for_field?).and_return(false)
      allow(Form).to receive(:has_submissions_for_field?).with(form.id, 'Remove').and_return(true)

      expect {
        FormService.update_form(user, form, { structure: { fields: [ { label: 'Keep', field_type: 'text' } ] } })
      }.to raise_error(FormService::DataLossWarning)
    end
  end
end
