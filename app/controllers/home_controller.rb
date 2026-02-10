class HomeController < ApplicationController

  skip_before_action :authenticate, only: [ :index ]
  def index
    render inertia: "Home/Index"
  end

end
