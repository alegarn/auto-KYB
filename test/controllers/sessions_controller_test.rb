require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:lazaro_nixon)
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
