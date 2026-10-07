# frozen_string_literal: true

class Dossiers::DegradedIdentiteEntrepriseComponent < ApplicationComponent
  attr_reader :siret, :profile, :token_rejected, :error_code

  def initialize(siret:, profile:, token_rejected: false, error_code: nil)
    @siret = siret
    @profile = profile
    @token_rejected = token_rejected
    @error_code = error_code
  end

  def call
    source = t('.source')
    header = safe_join([
      render(alert),
      render(Dossiers::AnnuaireEntrepriseLinkComponent.new(
        siret:,
        extra_class_names: 'pull-left'
      )),
    ])

    render Dossiers::ExternalChampComponent.new(source:, data:)
      .tap { it.with_header { header } }
  end

  def data
    [[Etablissement.human_attribute_name(:siret), helpers.pretty_siret(siret), data_to_copy: siret]]
  end

  # A refused token is the administration's business: to the usager we only
  # say the data is missing, without a delay we cannot promise.
  def alert_text
    return t('.unavailable_for_legal_reasons') if error_code == 451
    return t('.not_found') if error_code
    return t('.insee_down') if !token_rejected
    return t('.unavailable') if profile == 'usager'

    t('.token_rejected')
  end

  def alert
    texts = [alert_text]
    texts << t('.dossier_blocked') if profile == 'instructeur' && !error_code

    Dsfr::AlertComponent.new(state: :warning, size: :sm, extra_class_names: 'fr-mb-2w pull-left width-100').tap do
      it.with_body { safe_join(texts, tag.br) }
    end
  end
end
