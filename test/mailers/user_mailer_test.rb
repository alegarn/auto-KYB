require "test_helper"

class UserMailerTest < ActionMailer::TestCase

  setup do
    @user = users(:lazaro_nixon)
  end

  test "passwordless" do
    mail = UserMailer.with(user: @user).passwordless
    assert_equal "Your sign-in link", mail.subject
    assert_equal [ @user.email ], mail.to
  end

  test "email_verification" do
    mail = UserMailer.with(user: @user).email_verification
    assert_equal "Verify your email", mail.subject
    assert_equal [ @user.email ], mail.to
  end

end
