require "rails_helper"

RSpec.describe ClientPortal::FormResponseSaver, type: :service do
  let(:client_form) { create(:client_form) }
  let(:client) { client_form.client }

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

  it "enqueues CRM export when validate is true" do
    connection = create(:crm_connection, user: client.user, status: "active")

    saver = described_class.new(
      client_form: client_form,
      data: { a: 1 },
      validate: true,
      partial: false
    )

    expect {
      saver.save
    }.to have_enqueued_job(CrmDataExportJob)
  end

  it "does not enqueue CRM export when portal auto-sync is disabled" do
    create(:crm_connection, user: client.user, status: "active")
    client.user.update!(crm_auto_sync_on_portal_submit: false)

    saver = described_class.new(
      client_form: client_form,
      data: { a: 1 },
      validate: true,
      partial: false
    )

    expect {
      saver.save
    }.not_to have_enqueued_job(CrmDataExportJob)
  end
end
