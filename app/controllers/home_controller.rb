class HomeController < ApplicationController
  def index
    render inertia: true
  end
end
