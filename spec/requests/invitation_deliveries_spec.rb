require "rails_helper"

RSpec.describe "ClientFormInvitationDeliveries", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:user) { sign_in_user }
  let(:client) { FactoryBot.create(:client, user: user, email: "client@example.com") }
  let(:form) { FactoryBot.create(:form, user: user) }

  def create_invitation
    post client_forms_path, params: { client_form: { client_id: client.id, form_id: form.id } }
    ClientForm.order(:created_at).last
  end

  describe "GET /client_forms/:client_form_id/invitation_delivery" do
    it "renders the decision page when a live secret exists" do
      cf = create_invitation

      get client_form_invitation_delivery_path(cf)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("InvitationDeliveryDecision")
    end

    it "redirects to password_reveal if decision is no longer pending" do
      cf = create_invitation
      post client_form_invitation_delivery_path(cf), params: { send_now: "false" }

      get client_form_invitation_delivery_path(cf)
      expect(response).to redirect_to(password_reveal_client_form_path(cf))
    end

    context "when auto_send is enabled" do
      before do
        user.create_client_invitation_email_setting!(
          auto_send: true,
          body_template: "Hello {{client_name}}, link: {{invite_link}} password: {{password}}"
        )
      end

      it "renders the decision page with auto_send flag for frontend to handle" do
        cf = create_invitation

        get client_form_invitation_delivery_path(cf)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("InvitationDeliveryDecision")
        # auto_send prop is passed to the frontend which handles the POST
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it "falls back to manual decision when client has no email" do
        client.update!(email: nil)
        cf = create_invitation

        get client_form_invitation_delivery_path(cf)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("InvitationDeliveryDecision")
      end
    end
  end

  describe "POST /client_forms/:client_form_id/invitation_delivery" do
    context "with send_now: true" do
      it "sends the email and redirects to password_reveal with a success notice" do
        cf = create_invitation

        expect {
          post client_form_invitation_delivery_path(cf), params: { send_now: "true" }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to(password_reveal_client_form_path(cf))
        expect(flash[:notice]).to include("client@example.com")

        cf.reload
        expect(cf.invitation_emailed_at).to be_present
        expect(cf.invitation_emailed_to).to eq("client@example.com")
      end

      it "rejects sending when client has no email" do
        client.update!(email: nil)
        cf = create_invitation

        post client_form_invitation_delivery_path(cf), params: { send_now: "true" }
        expect(response).to redirect_to(client_form_invitation_delivery_path(cf))
        expect(flash[:alert]).to include("email")
      end

      it "handles expired session secret gracefully" do
        cf = create_invitation
        travel 6.minutes

        post client_form_invitation_delivery_path(cf), params: { send_now: "true" }
        expect(response).to redirect_to(password_reveal_client_form_path(cf))
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context "with send_now: false (Not now)" do
      it "skips email and redirects to password_reveal" do
        cf = create_invitation

        post client_form_invitation_delivery_path(cf), params: { send_now: "false" }
        expect(response).to redirect_to(password_reveal_client_form_path(cf))
        expect(ActionMailer::Base.deliveries.count).to eq(0)

        cf.reload
        expect(cf.invitation_emailed_at).to be_nil
      end
    end

    context "authorization" do
      it "rejects access from a different user" do
        cf = create_invitation
        other_user = sign_in_user # switches to new user

        get client_form_invitation_delivery_path(cf)
        expect(response).to redirect_to(clients_path)
      end
    end
  end
end
