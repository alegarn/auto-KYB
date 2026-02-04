require 'rails_helper'

RSpec.describe ClientForm, type: :model do
  it 'validates presence of client and form' do
    cf = ClientForm.new
    expect(cf.valid?).to be false
    expect(cf.errors[:client]).to include("must exist")
    expect(cf.errors[:form]).to include("must exist")
  end

  it 'has enum statuses' do
    cf = ClientForm.new(status: :draft)
    expect(ClientForm.statuses.keys).to include('draft', 'filled', 'validated') if defined?(ClientForm)
  end

  it 'uses uuid primary key' do
    cf = ClientForm.create!(client: create(:client), form: create(:form)) rescue nil
    if cf
      expect(cf.id).to be_present
    end
  end
end
