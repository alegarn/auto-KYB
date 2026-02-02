module TestAuthHelpers
  def sign_in_user(user = nil)
    user ||= FactoryBot.create(:user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end

  def current_user
    TestAuthHelpers::CURRENT_USER
  end
end

RSpec.configure do |config|
  config.include TestAuthHelpers
end
