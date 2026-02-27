class CrmTransfersController < ApplicationController
  def index
    # Dummy controller for UI phase
    render inertia: "CrmTransfers/Index"
  end
end
