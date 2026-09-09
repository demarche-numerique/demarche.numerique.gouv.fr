# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :application_base_url
  attribute :application_name
  attribute :browser
  attribute :contact_email
  attribute :host
  attribute :job_id
  attribute :no_reply_email
  attribute :request_id
  attribute :user
  attribute :session_end_reason
  attribute :user_session_id
  attribute :procedure_columns
end
