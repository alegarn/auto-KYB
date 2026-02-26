class HomeController < ApplicationController

  skip_before_action :authenticate, only: [ :index ]
  after_action :verify_authorized, except: :index
  before_action :skip_authorization

  def index
    render inertia: "Home/Index"
  end

end
