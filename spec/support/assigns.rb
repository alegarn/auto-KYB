# Minimal `assigns` helper for controller specs (avoids adding rails-controller-testing gem)
module SpecAssignsHelper
  def assigns(key = nil)
    return controller.view_assigns unless key
    controller.instance_variable_get("@#{key}")
  end
end

RSpec.configure do |config|
  config.include SpecAssignsHelper, type: :controller
end
