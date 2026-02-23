class QuickstartController < ApplicationController
  skip_before_action :authenticate, only: [ :index ]

  def index
    render inertia: "Public/Quickstart/Index"
  end
end
