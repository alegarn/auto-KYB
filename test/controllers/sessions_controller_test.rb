require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:lazaro_nixon)
    @user.update!(subscription_status: "active")
  end

  test "should get index" do
    sign_in_as @user

    get sessions_url
    assert_response :success
  end

  test "should get new" do
    get sign_in_url
    assert_response :success
  end

  test "should request magic link for verified user" do
    assert_enqueued_email_with UserMailer, :passwordless, params: { user: @user } do
      post sign_in_url, params: { email: @user.email }
    end

    assert_redirected_to sign_in_url
  end

  test "should not send magic link for canceled account beyond retention window" do
    stale_canceled_user = User.create!(
      email: "stale-canceled@example.com",
      password: "Secret1*3*5*",
      verified: true,
      subscription_status: "canceled",
      subscription_canceled_at: 2.years.ago
    )

    assert_no_enqueued_emails do
      post sign_in_url, params: { email: stale_canceled_user.email }
    end

    assert_redirected_to sign_in_url
  end

  test "should not leak existence for unknown email" do
    assert_no_enqueued_emails do
      post sign_in_url, params: { email: "unknown@example.com" }
    end

    assert_redirected_to sign_in_url
  end

  test "should sign out" do
    sign_in_as @user

    delete session_url(@user.sessions.last)
    assert_redirected_to sessions_url

    follow_redirect!
    assert_redirected_to sign_in_url
  end

end
