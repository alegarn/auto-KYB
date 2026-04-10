require "test_helper"

class SessionsControllerOmniauthTest < ActionController::TestCase

  tests SessionsController

  setup do
    @provider = "google_oauth2"
    @uid = "google-uid-123"
  end

  test "does not create a new user for unknown oauth identity on sign in" do
    @request.env["omniauth.auth"] = omniauth_hash(email: "unknown@example.com", uid: "unknown-uid")

    assert_no_difference("User.count") do
      assert_no_difference("Session.count") do
        get :omniauth, params: { provider: @provider }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal "We could not sign you in with Google", flash[:alert]
  end

  test "allows oauth sign in for canceled account within retention window" do
    user = User.create!(
      email: "recent-canceled@example.com",
      password: "Secret1*3*5*",
      verified: true,
      provider: @provider,
      uid: @uid,
      onboarding_completed: true,
      subscription_status: "canceled",
      subscription_canceled_at: 6.months.ago
    )

    @request.env["omniauth.auth"] = omniauth_hash(email: user.email, uid: user.uid)

    assert_difference("Session.count", 1) do
      get :omniauth, params: { provider: @provider }
    end

    assert_redirected_to auth_loading_path
  end

  test "rejects oauth sign in for canceled account beyond retention window" do
    user = User.create!(
      email: "stale-canceled-oauth@example.com",
      password: "Secret1*3*5*",
      verified: true,
      provider: @provider,
      uid: "stale-uid",
      onboarding_completed: true,
      subscription_status: "canceled",
      subscription_canceled_at: 2.years.ago
    )

    @request.env["omniauth.auth"] = omniauth_hash(email: user.email, uid: user.uid)

    assert_no_difference("Session.count") do
      get :omniauth, params: { provider: @provider }
    end

    assert_redirected_to sign_in_path
    assert_equal "We could not sign you in with Google", flash[:alert]
  end

  private

  def omniauth_hash(email:, uid:)
    {
      "provider" => @provider,
      "uid" => uid,
      "info" => {
        "email" => email
      }
    }
  end

end
