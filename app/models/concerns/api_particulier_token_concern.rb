# frozen_string_literal: true

module APIParticulierTokenConcern
  extend ActiveSupport::Concern

  def api_particulier_token?
    self[:api_particulier_token].present?
  end
end
