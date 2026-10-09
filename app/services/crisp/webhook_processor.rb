# frozen_string_literal: true

module Crisp
  class WebhookProcessor
    include Dry::Monads[:result]

    # IMPORTANT: Outgoing traffic is restricted in production: never call the Crisp API from a webhook request, use a job!
    def initialize(params)
      @params = params
      @email = extract_email_from_params
      @session_id = params.dig(:data, :session_id)
    end

    def process
      case params[:event]
      when "message:send"
        process_message_send
      when "session:set_inbox"
        process_inbox_change
      end
    end

    private

    attr_reader :params, :session_id, :email

    def process_message_send
      return unless params.dig(:data, :from) == "user"

      CrispUpdatePeopleDataJob.perform_later(session_id, email)
    end

    def process_inbox_change
      # inbox_id = params.dig(:data, :inbox_id)
      # Note: as of 3 sept 2025, crisp has a known bug: new inbox_id is empty,
      # we have to call API to get the id

      CrispTchapTechNotificationJob.perform_later(session_id)
    end

    def extract_email_from_params
      # conversations from chat does not use an email as user id
      maybe_email = params.dig(:data, :user, :user_id)
      maybe_email&.include?("@") ? maybe_email : nil
    end
  end
end
