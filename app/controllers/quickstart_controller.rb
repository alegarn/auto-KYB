class QuickstartController < ApplicationController

  skip_before_action :authenticate, only: [ :index ]
  before_action :skip_authorization

  def index
    render inertia: "Public/Quickstart/Index"
  end

end
