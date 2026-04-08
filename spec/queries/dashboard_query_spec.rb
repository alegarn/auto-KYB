require "rails_helper"

RSpec.describe DashboardQuery do
  let(:route_helpers) { Rails.application.routes.url_helpers }

  describe "#onboarding_summary" do
    it "returns the basic variant for subscribed basic users" do
      user = create(:user, :subscribed, plan: :basic)

      summary = described_class.new(user).onboarding_summary

      expect(summary).to include(
        visible: true,
        variant: "basic",
        progress_percent: 25,
        completion_rule: "basic_core",
        can_dismiss: true,
        detailed_view_seen: false
      )
      expect(summary[:quick_steps]).to eq([
        { key: "form", complete: true, href: route_helpers.edit_form_path(user.forms.order(updated_at: :desc).pick(:id)) },
        { key: "client", complete: false, href: route_helpers.new_client_path },
        { key: "invite", complete: false, href: route_helpers.new_client_path },
        { key: "review", complete: false, href: route_helpers.clients_path }
      ])
    end

    it "returns the pro variant for CRM-entitled users and keeps the CRM step incomplete until connected" do
      user = create(:user, :subscribed, plan: :pro)
      client = create(:client, user: user)
      create(:client_form, client: client, form: user.forms.first)

      summary = described_class.new(user).onboarding_summary

      expect(summary).to include(
        visible: true,
        variant: "pro",
        progress_percent: 60,
        completion_rule: "pro_with_crm"
      )
      expect(summary[:quick_steps].map { |step| step[:key] }).to eq(%w[form client invite review crm])
      expect(summary[:quick_steps].last).to eq(
        key: "crm",
        complete: false,
        href: route_helpers.settings_path
      )
    end

    it "hides onboarding after dismissal" do
      user = create(:user, :subscribed, plan: :basic)
      user.dismiss_dashboard_onboarding!

      summary = described_class.new(user).onboarding_summary

      expect(summary[:visible]).to be(false)
    end

    it "hides onboarding after form, client, and invite are complete for basic users" do
      user = create(:user, :subscribed, plan: :basic)
      client = create(:client, user: user, form_status: "validated")
      create(:client_form, client: client, form: user.forms.first)

      summary = described_class.new(user).onboarding_summary

      expect(summary).to include(
        visible: false,
        progress_percent: 100,
        variant: "basic"
      )
    end

    it "hides onboarding after form, client, invite, review and CRM are complete for entitled users" do
      user = create(:user, :subscribed, plan: :pro)
      client = create(:client, user: user, form_status: "validated")
      create(:client_form, client: client, form: user.forms.first)
      create(:crm_connection, user: user, status: "active")

      summary = described_class.new(user).onboarding_summary

      expect(summary).to include(
        visible: false,
        progress_percent: 100,
        variant: "pro"
      )
    end

    it "exposes detailed_view_seen from the dashboard onboarding state" do
      user = create(:user, :subscribed, plan: :basic)
      user.mark_dashboard_onboarding_details_seen!

      summary = described_class.new(user).onboarding_summary

      expect(summary[:detailed_view_seen]).to be(true)
    end
  end
end