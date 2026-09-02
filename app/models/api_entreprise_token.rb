# frozen_string_literal: true

class APIEntrepriseToken
  include ExpiringJwtTokenConcern

  TokenError = Class.new(StandardError)

  def can_fetch_attestation_sociale?
    # https://github.com/etalab/admin_api_entreprise/blob/6f5c7ecbe94af8d5403dbff320af56e8797f3fc6/app/policies/download_attestations_policy.rb#L16
    ['attestation_sociale', 'attestation_sociale_urssaf']
      .any? { |r| roles.include?(r) }
  end

  def can_fetch_attestation_fiscale?
    # https://github.com/etalab/admin_api_entreprise/blob/6f5c7ecbe94af8d5403dbff320af56e8797f3fc6/app/policies/download_attestations_policy.rb#L20
    ["attestation_fiscale", "attestation_fiscale_dgfip"]
      .any? { |r| roles.include?(r) }
  end

  def can_fetch_bilans_bdf?
    roles.include?("bilans_entreprise_bdf")
  end

  private

  def roles
    Array(decoded_token["roles"] || decoded_token["scopes"])
  end
end
