# frozen_string_literal: true

module APIEntrepriseTokenConcern
  extend ActiveSupport::Concern

  included do
    validates_associated :api_entreprise_token

    before_save :forget_api_entreprise_token_rejection, if: :will_save_change_to_api_entreprise_token?
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
    api_entreprise_token_rejected_at&.after?(TOKEN_REJECTION_HOLDS_FOR.ago) || false
  end

  # Every dossier of the procedure hits the same wall: record it once.
  def reject_api_entreprise_token!
    Rails.logger.error("API Entreprise rejected the token of procedure #{id}")

    # Nobody can renew the instance token from the interface: blocking the
    # procedure would have no way out. We keep retrying and wake up operations.
    if !specific_api_entreprise_token?
      return Sentry.capture_message("Global API Entreprise token rejected", level: :error, extra: { procedure_id: id })
    end

    update_column(:api_entreprise_token_rejected_at, Time.current)
  end

  # A call went through: whoever repaired the token, it works again.
  def forget_api_entreprise_token_rejection!
    return if api_entreprise_token_rejected_at.nil?

    update_column(:api_entreprise_token_rejected_at, nil)
  end

  private

  def forget_api_entreprise_token_rejection
    self.api_entreprise_token_rejected_at = nil
  end
end
