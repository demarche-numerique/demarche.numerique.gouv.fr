# frozen_string_literal: true

class WebhookEvent < ApplicationRecord
  RETENTION_PERIOD = 7.days

  belongs_to :procedure

  scope :retention_expired, -> { where(created_at: ...RETENTION_PERIOD.ago) }
end
