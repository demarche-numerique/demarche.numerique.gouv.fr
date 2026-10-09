# frozen_string_literal: true

module Manager
  class ApplicationController < Administrate::ApplicationController
    include RequiresEnrolledSuperAdminOtp

    protect_from_forgery with: :exception, store: :cookie
    before_action :authenticate_super_admin!
    before_action :default_params

    def default_params
      request.query_parameters[resource_name] ||= {
        order: "id",
        direction: "desc",
      }
    end

    def message_encryptor_service
      @message_encryptor_service ||= MessageEncryptorService.new
    end

    private

    def sorting_attribute
      attribute = super

      # do not sort by non-indexed created_at. This require a full table scan, locking every other transactions.
      return :id if attribute.to_sym == :created_at

      attribute
    end

    # private method called by rails fwk
    # see https://github.com/roidrage/lograge
    def append_info_to_payload(payload)
      super

      to_log = {
        user_agent: request.user_agent,
        user_id: current_user&.id,
        user_email: current_user&.email,
        super_admin_id: current_super_admin&.id,
        client_ip: request.remote_ip,
      }

      if browser.known?
        to_log.merge!({
          browser: browser.name,
          browser_version: browser.version.to_s,
          platform: browser.platform.name,
        })
      end

      payload[:to_log] = to_log
    end

    def generate_csv(users)
      CSV.generate(headers: true) do |csv|
        csv << ['ID', 'Email', 'Date de création']
        users.each do |user|
          csv << [user.id, user.email, user.created_at]
        end
      end
    end
  end
end
