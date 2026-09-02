# frozen_string_literal: true

module APIParticulierTokenConcern
  extend ActiveSupport::Concern

  included do
    # Uniquement à la saisie : des jetons illisibles sont déjà en base, et une
    # validation inconditionnelle rendrait ces démarches insauvegardables.
    validates_associated :api_particulier_token, if: :will_save_change_to_api_particulier_token?
  end

  def api_particulier_token
    APIParticulierToken.new(self[:api_particulier_token])
  end

  def api_particulier_token?
    self[:api_particulier_token].present?
  end
end
