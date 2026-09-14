# frozen_string_literal: true

module APIEntrepriseTokenConcern
  extend ActiveSupport::Concern

  included do
    validates_associated :api_entreprise_token

    before_save :clear_api_entreprise_token_rejection, if: :will_save_change_to_api_entreprise_token?
  end

  def api_entreprise_token
    t = self[:api_entreprise_token].presence || ENV['API_ENTREPRISE_KEY']

    APIEntrepriseToken.new(t)
  end

  def specific_api_entreprise_token?
    self[:api_entreprise_token].present?
  end

  # Beyond that delay we try again, so a token repaired outside the form does
  # not leave the procedure blocked.
  TOKEN_REJECTION_HOLDS_FOR = 24.hours

  def api_entreprise_token_recently_rejected?
    api_entreprise_token_rejected_at&.after?(TOKEN_REJECTION_HOLDS_FOR.ago)
  end

  # Only called for a token of the procedure's own: nobody could renew the
  # instance one from the interface, so blocking on it would have no way out.
  def mark_api_entreprise_token_as_rejected!
    Rails.logger.error("API Entreprise rejected the token of procedure #{id}")

    update_column(:api_entreprise_token_rejected_at, Time.current)
  end

  def forget_api_entreprise_token_rejection!
    return if api_entreprise_token_rejected_at.nil?

    update_column(:api_entreprise_token_rejected_at, nil)
  end

  def api_entreprise_token_usable?
    return false if api_entreprise_token_recently_rejected?
    api_entreprise_token.usable?
  end

  private

  def clear_api_entreprise_token_rejection
    self.api_entreprise_token_rejected_at = nil
  end
end
