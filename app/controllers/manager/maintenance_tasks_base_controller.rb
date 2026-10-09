# frozen_string_literal: true

module Manager
  class MaintenanceTasksBaseController < ActionController::Base
    private

    def append_info_to_payload(payload)
      super

      payload[:to_log] = {
        super_admin_id: current_super_admin.id,
        client_ip: request.remote_ip,
      }
    end
  end
end
