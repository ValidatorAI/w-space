class DebugController < ApplicationController
  before_action :ensure_admin_debug_enabled
  before_action :ensure_can_administer

  def show
  end

  private
    def ensure_admin_debug_enabled
      return if ENV.fetch("ADMIN_DEBUG", ENV.fetch("admin_debug", "false")).to_s.strip.casecmp("true").zero?

      head :not_found
    end
end
