require "rails_helper"

RSpec.describe ClientPortal::FormResponseSaver, type: :service do
  let(:client_form) { create(:client_form) }

  it "normalizes ActionController::Parameters data" do
    params = ActionController::Parameters.new({
      foo: "bar",
      nested: { a: 1 }
    })

    saver = described_class.new(
      client_form: client_form,
      data: params,
      validate: false,
      partial: false
    )

    result = saver.save

    expect(result.response.data).to include(
      "foo" => "bar",
      "nested" => { "a" => 1 }
    )
  end
end
