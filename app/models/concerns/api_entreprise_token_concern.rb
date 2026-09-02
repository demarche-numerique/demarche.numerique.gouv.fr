# frozen_string_literal: true

module APIEntrepriseTokenConcern
  extend ActiveSupport::Concern

  included do
    validates_associated :api_entreprise_token
  end

  def api_entreprise_token
    t = self[:api_entreprise_token].presence || ENV['API_ENTREPRISE_KEY']

    APIEntrepriseToken.new(t)
  end

  def specific_api_entreprise_token?
    self[:api_entreprise_token].present?
  end

  # Le jeton global de l'instance n'est pas à la main de l'administrateur : il n'a
  # rien à renouveler, et rien ne doit l'alerter à son sujet.
  def api_entreprise_token_needs_renewal?
    specific_api_entreprise_token? && api_entreprise_token.needs_renewal?
  end
end
