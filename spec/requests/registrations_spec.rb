# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  # ─────────────────────────────────────────────────────────────
  # GET /sign_up
  # ─────────────────────────────────────────────────────────────
  describe "GET /sign_up" do
    it "returns 200" do
      get sign_up_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /registrations/complete  (Pay First – post-checkout)
  # ─────────────────────────────────────────────────────────────
  describe "GET /registrations/complete" do
    let(:session_id) { "cs_test_123" }
    let(:paid_checkout_session) do
      double(
        payment_status:   'paid',
        customer:         'cus_new_123',
        subscription:     'sub_new_abc',
        customer_details: double(email: 'welcome@example.com')
      )
    end

    context "when session_id param is missing" do
      it "redirects to sign_in with a notice" do
        get complete_registration_path
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "with a valid paid Stripe session for a brand-new user" do
      before do
        allow(Stripe::Checkout::Session)
          .to receive(:retrieve).with(session_id)
          .and_return(paid_checkout_session)
      end

      it "creates a new user with active subscription" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.to change(User, :count).by(1)

        user = User.find_by(stripe_customer_id: 'cus_new_123')
        expect(user.email).to eq('welcome@example.com')
        expect(user.subscription_status).to eq('active')
        expect(user.stripe_subscription_id).to eq('sub_new_abc')
        expect(user.verified).to be true
      end

      it "enqueues the welcome email" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.to have_enqueued_mail(UserMailer, :welcome)
      end

      it "returns 200" do
        get complete_registration_path, params: { session_id: session_id }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when a matching user already exists by stripe_customer_id" do
      let!(:existing_user) do
        # Use the same email as the Stripe session to avoid the email-change
        # before_validation callback which resets verified: false
        create(:user, email: 'welcome@example.com', stripe_customer_id: 'cus_new_123',
               subscription_status: 'incomplete', verified: false)
      end

      before do
        allow(Stripe::Checkout::Session)
          .to receive(:retrieve).with(session_id)
          .and_return(paid_checkout_session)
      end

      it "updates the existing user without creating a new one" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.not_to change(User, :count)

        existing_user.reload
        expect(existing_user.subscription_status).to eq('active')
        expect(existing_user.verified).to be true
      end

      it "enqueues the welcome email" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.to have_enqueued_mail(UserMailer, :welcome)
      end
    end

    context "when a canceled user resubscribes (clears subscription_canceled_at)" do
      let!(:canceled_user) do
        create(:user, :canceled,
               email:              'welcome@example.com',
               stripe_customer_id: 'cus_new_123',
               subscription_ends_at: 1.day.ago)
      end

      before do
        allow(Stripe::Checkout::Session)
          .to receive(:retrieve).with(session_id)
          .and_return(paid_checkout_session)
      end

      it "clears subscription_canceled_at when reactivating" do
        get complete_registration_path, params: { session_id: session_id }
        canceled_user.reload
        expect(canceled_user.subscription_canceled_at).to be_nil
      end

      it "sets subscription_status to active" do
        get complete_registration_path, params: { session_id: session_id }
        expect(canceled_user.reload.subscription_status).to eq('active')
      end
    end

    context "when payment is not completed (unpaid status)" do
      before do
        unpaid = instance_double(
          "Stripe::Checkout::Session",
          payment_status:   'unpaid',
          customer:         'cus_fail',
          customer_details: double(email: 'x@example.com')
        )
        allow(Stripe::Checkout::Session)
          .to receive(:retrieve).with(session_id)
          .and_return(unpaid)
      end

      it "redirects to sign_up with an alert" do
        get complete_registration_path, params: { session_id: session_id }
        expect(response).to redirect_to(sign_up_path)
        expect(flash[:alert]).to be_present
      end

      it "does not create a user" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.not_to change(User, :count)
      end
    end

    context "when Stripe raises an error" do
      before do
        allow(Stripe::Checkout::Session)
          .to receive(:retrieve)
          .and_raise(Stripe::StripeError.new("Network error"))
      end

      it "redirects to sign_up with an alert" do
        get complete_registration_path, params: { session_id: session_id }
        expect(response).to redirect_to(sign_up_path)
        expect(flash[:alert]).to be_present
      end

      it "does not create a user" do
        expect {
          get complete_registration_path, params: { session_id: session_id }
        }.not_to change(User, :count)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /registrations/recover  (Recovery link from welcome email)
  # ─────────────────────────────────────────────────────────────
  describe "GET /registrations/recover" do
    let(:user) { create(:user, :subscribed, stripe_customer_id: 'cus_recover') }

    context "with a valid recovery token" do
      it "creates a session and redirects to auth_loading" do
        token = user.generate_token_for(:stripe_customer_recovery)

        expect {
          get recover_registration_path, params: { token: token }
        }.to change(Session, :count).by(1)

        expect(response).to redirect_to(auth_loading_path)
        expect(flash[:notice]).to be_present
      end

      it "sets a session cookie in the response" do
        token = user.generate_token_for(:stripe_customer_recovery)
        get recover_registration_path, params: { token: token }

        expect(response.cookies["session_token"]).to be_present
      end
    end

    context "with an invalid or expired token" do
      it "redirects to sign_in with an alert" do
        get recover_registration_path, params: { token: "invalid-token" }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to include("invalid or has expired")
      end

      it "does not create a session" do
        expect {
          get recover_registration_path, params: { token: "bad" }
        }.not_to change(Session, :count)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /sign_up  (Account deletion)
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /sign_up" do
    let!(:user) { create(:user, :subscribed) }
    let!(:session_record) { user.sessions.create! }

    before { cookies.signed[:session_token] = session_record.id }

    context "with invalid confirmation string" do
      it "does not delete the account" do
        expect {
          delete sign_up_path, params: { confirmation: "WRONG" }
        }.not_to change(User, :count)
      end

      it "redirects to settings with an alert" do
        delete sign_up_path, params: { confirmation: "WRONG" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "with valid confirmation when user has a stripe_subscription_id" do
      before do
        user.update!(stripe_subscription_id: "sub_to_cancel")
        allow(Stripe::Subscription).to receive(:cancel).with("sub_to_cancel")
          .and_return(double(status: 'canceled'))
      end

      it "cancels the Stripe subscription" do
        expect(Stripe::Subscription).to receive(:cancel).with("sub_to_cancel")
          .and_return(double(status: 'canceled'))
        delete sign_up_path, params: { confirmation: "DELETE" }
      end

      it "deletes the user" do
        expect {
          delete sign_up_path, params: { confirmation: "DELETE" }
        }.to change(User, :count).by(-1)
      end

      it "destroys all associated sessions" do
        delete sign_up_path, params: { confirmation: "DELETE" }
        expect(Session.exists?(id: session_record.id)).to be false
      end

      it "redirects to root with a notice" do
        delete sign_up_path, params: { confirmation: "DELETE" }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_present
      end

      it "clears oauth linkage before deleting the account" do
        user.update!(provider: "google_oauth2", uid: "oauth-uid")

        expect_any_instance_of(User)
          .to receive(:update!)
          .with(hash_including(provider: nil, uid: nil))
          .and_call_original

        delete sign_up_path, params: { confirmation: "DELETE" }
      end
    end

    context "when oauth is connected and destroy fails" do
      let!(:user) { create(:user, :subscribed, provider: "google_oauth2", uid: "oauth-uid") }
      let!(:session_record) { user.sessions.create! }

      before do
        cookies.signed[:session_token] = session_record.id
        user.update!(stripe_subscription_id: nil, stripe_customer_id: nil)
        allow_any_instance_of(User)
          .to receive(:destroy!)
          .and_raise(ActiveRecord::RecordNotDestroyed.new("fail", nil))
      end

      it "still clears oauth linkage" do
        delete sign_up_path, params: { confirmation: "DELETE" }

        user.reload
        expect(user.provider).to be_nil
        expect(user.uid).to be_nil
      end

      it "redirects back to settings with an alert" do
        delete sign_up_path, params: { confirmation: "DELETE" }

        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "with valid confirmation and dependent records (cascade check)" do
      before do
        allow(Stripe::Subscription).to receive(:cancel).and_return(double(status: 'canceled'))
        user.update!(stripe_subscription_id: "sub_cascade")
      end

      it "also destroys forms, clients and their nested records" do
        form       = user.forms.create!(name: "KYB Form")
        ff         = form.form_fields.create!(label: "Company name", field_type: "text", required: true)
        client     = user.clients.create!(name: "Alice", company_name: "Acme")
        cf         = ClientForm.create!(client: client, form: form)
        fr         = FormResponse.create!(client_form: cf, data: { company_name: "Acme" })

        delete sign_up_path, params: { confirmation: "DELETE" }

        expect(Form.exists?(form.id)).to be false
        expect(FormField.exists?(ff.id)).to be false
        expect(Client.exists?(client.id)).to be false
        expect(ClientForm.exists?(cf.id)).to be false
        expect(FormResponse.exists?(fr.id)).to be false
        expect(Session.exists?(session_record.id)).to be false
      end
    end

    context "with valid confirmation when no subscription_id (lookup by customer)" do
      before do
        user.update!(stripe_subscription_id: nil, stripe_customer_id: "cus_listed")
        active_sub = double(id: "sub_found", status: "active")
        allow(Stripe::Subscription)
          .to receive(:list)
          .with(customer: "cus_listed", status: "all", limit: 10)
          .and_return(double(data: [ active_sub ]))
        allow(Stripe::Subscription).to receive(:cancel).with("sub_found")
          .and_return(double(status: 'canceled'))
      end

      it "deletes the user" do
        expect {
          delete sign_up_path, params: { confirmation: "DELETE" }
        }.to change(User, :count).by(-1)
      end
    end

    context "with valid confirmation when no Stripe identifiers" do
      before { user.update!(stripe_subscription_id: nil, stripe_customer_id: nil) }

      it "deletes the user without calling Stripe" do
        expect(Stripe::Subscription).not_to receive(:cancel)
        expect {
          delete sign_up_path, params: { confirmation: "DELETE" }
        }.to change(User, :count).by(-1)
      end
    end

    context "when Stripe cancellation fails with a network error" do
      before do
        user.update!(stripe_subscription_id: "sub_bad")
        allow(Stripe::Subscription)
          .to receive(:cancel)
          .and_raise(Stripe::StripeError.new("service unavailable"))
      end

      it "does not delete the user" do
        expect {
          delete sign_up_path, params: { confirmation: "DELETE" }
        }.not_to change(User, :count)
      end

      it "redirects to settings with an alert" do
        delete sign_up_path, params: { confirmation: "DELETE" }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /sign_up  — unauthenticated (separate describe, no cookie before)
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /sign_up when unauthenticated" do
    it "redirects to sign_in" do
      delete sign_up_path, params: { confirmation: "DELETE" }
      expect(response).to redirect_to(sign_in_path)
    end
  end
end
