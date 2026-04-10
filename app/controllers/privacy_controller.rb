class PrivacyController < ApplicationController

  skip_before_action :authenticate, only: :show
  before_action :skip_authorization

  def show
    render inertia: "Privacy/Show", props: {
      retention_days: CrmTransfer::RETENTION_PERIOD / 1.day
    }
  end

end
