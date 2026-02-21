require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest

  test "should get new" do
    get sign_up_url
    assert_response :success
  end

  test "should sign up" do
    assert_difference("User.count") do
      post sign_up_url, params: { email: "lazaronixon@hey.com" }
    end

    assert_redirected_to sign_in_url
  end

end
