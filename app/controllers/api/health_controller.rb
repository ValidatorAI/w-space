module Api
  class HealthController < Api::BaseController
    def show
      Project.count
      render json: { status: "ok", app_version: ENV["APP_VERSION"], db: "up" }
    end
  end
end
