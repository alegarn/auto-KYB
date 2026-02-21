require "test_helper"

class Sessions::PasswordlessesControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:lazaro_nixon)
  end

  test "should sign in with valid sid" do
    sid = @user.generate_token_for(:signin)

    get passwordless_sign_in_url(sid: sid)
    assert_redirected_to auth_loading_url

    follow_redirect!
    assert_response :success
  end

  test "should reject invalid sid" do
    get passwordless_sign_in_url(sid: "invalid")

    assert_redirected_to sign_in_url
    assert_equal "That sign in link is invalid or expired", flash[:alert]
  end

end
