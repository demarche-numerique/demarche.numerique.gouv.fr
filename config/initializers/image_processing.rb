# frozen_string_literal: true

if ENV.enabled?("DISABLE_IMAGE_PROCESSING")
  Rails.application.config.active_storage.variable_content_types = []
  Rails.application.config.active_storage.previewers = []
end
