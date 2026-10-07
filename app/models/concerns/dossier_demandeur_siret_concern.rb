# frozen_string_literal: true

module DossierDemandeurSiretConcern
  extend ActiveSupport::Concern

  def demandeur_siret_awaiting_fix? = demandeur_siret&.awaiting_fix? || false

  def siret = etablissement&.siret || demandeur_siret&.siret

  def siren = etablissement ? etablissement.siren : demandeur_siret&.siret&.first(9)

  def demandeur_siret_component_args(profile)
    {
      siret: demandeur_siret.siret,
      profile:,
      token_rejected: procedure.api_entreprise_token_rejected? || !procedure.api_entreprise_token.usable?,
      error_code: (demandeur_siret.fetch_external_data_exceptions.last&.code if demandeur_siret.external_error?),
    }
  end
end
