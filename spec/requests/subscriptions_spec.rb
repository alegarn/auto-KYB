# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Subscriptions", type: :request do
  # ─────────────────────────────────────────────────────────────
  # GET /subscription/required
  # ─────────────────────────────────────────────────────────────
  describe "GET /subscription/required" do
    it "renders 200 for unauthenticated visitors" do
      get subscription_required_path
      expect(response).to have_http_status(:ok)
    end

    it "renders 200 for an authenticated user with a canceled subscription" do
      user           = create(:user, :canceled)
      session_record = user.sessions.create!
      cookies.signed[:session_token] = session_record.id

      get subscription_required_path
      expect(response).to have_http_status(:ok)
    end

    it "renders 200 for an authenticated active subscriber (exempt page)" do
      user           = create(:user, :subscribed)
      session_record = user.sessions.create!
      cookies.signed[:session_token] = session_record.id

      get subscription_required_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /subscriptions/billing_portal
  # ─────────────────────────────────────────────────────────────
  describe "POST /subscriptions/billing_portal" do
    let(:portal_url) { "https://billing.stripe.com/p/session/test_abc" }
    let(:stripe_session) { double(url: portal_url) }

    context "when unauthenticated" do
      it "redirects to sign_in" do
        post "/subscriptions/billing_portal"
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when authenticated with an existing stripe_customer_id" do
      let!(:user) { create(:user, :canceled, stripe_customer_id: "cus_existing") }
      let!(:session_record) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session_record.id
        allow(Stripe::BillingPortal::Session)
          .to receive(:create)
          .and_return(stripe_session)
      end

      it "returns JSON with the billing portal url" do
        post "/subscriptions/billing_portal"
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["url"]).to eq(portal_url)
      end

      it "calls the Stripe billing portal API with the customer id" do
        expect(Stripe::BillingPortal::Session).to receive(:create).with(
          hash_including(customer: "cus_existing")
        )
        post "/subscriptions/billing_portal"
      end
    end

    context "when authenticated without a stripe_customer_id" do
      let!(:user) { create(:user, :canceled, stripe_customer_id: nil) }
      let!(:session_record) { user.sessions.create! }
      let(:new_customer) { double(id: "cus_brand_new") }

      before do
        cookies.signed[:session_token] = session_record.id
        allow(Stripe::Customer)
          .to receive(:create)
          .and_return(new_customer)
        allow(Stripe::BillingPortal::Session)
          .to receive(:create)
          .and_return(stripe_session)
      end

      it "creates a Stripe customer and persists the id" do
        post "/subscriptions/billing_portal"
        expect(user.reload.stripe_customer_id).to eq("cus_brand_new")
      end

      it "returns JSON with the billing portal url" do
        post "/subscriptions/billing_portal"
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["url"]).to eq(portal_url)
      end
    end

    context "when Stripe raises an InvalidRequestError with a non-customer error" do
      let!(:user) { create(:user, :canceled, stripe_customer_id: "cus_stale") }
      let!(:session_record) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session_record.id
        # Use a message that does NOT match missing_customer_error? so the controller
        # goes directly to the bad_gateway branch (not the customer-recreation branch)
        allow(Stripe::BillingPortal::Session)
          .to receive(:create)
          .and_raise(Stripe::InvalidRequestError.new("Invalid billing portal configuration", "configuration"))
      end

      it "returns a JSON error with bad_gateway status" do
        post "/subscriptions/billing_portal"
        expect(response).to have_http_status(:bad_gateway)
        body = JSON.parse(response.body)
        expect(body["error"]).to be_present
      end
    end
  end
end
