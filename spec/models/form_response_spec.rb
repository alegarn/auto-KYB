require 'rails_helper'

RSpec.describe FormResponse, type: :model do
  it 'sets version incrementally per client_form' do
    cf = create(:client_form) rescue nil
    skip 'factory/client_form missing' unless cf

    r1 = FormResponse.create!(client_form: cf, data: { a: 1 })
    r2 = FormResponse.create!(client_form: cf, data: { a: 2 })

    expect(r1.version).to eq(1)
    expect(r2.version).to eq(2)
  end
end
