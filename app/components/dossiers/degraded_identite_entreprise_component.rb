# frozen_string_literal: true

class Dossiers::DegradedIdentiteEntrepriseComponent < ApplicationComponent
  attr_reader :siret, :profile, :token_rejected

  def initialize(siret:, profile:, token_rejected: false)
    @siret = siret
    @profile = profile
    @token_rejected = token_rejected
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

  def alert
    texts = [token_rejected ? t('.token_rejected') : t('.insee_down')]
    texts << t('.dossier_blocked') if profile == 'instructeur'

    Dsfr::AlertComponent.new(state: :warning, size: :sm, extra_class_names: 'fr-mb-2w pull-left width-100').tap do
      it.with_body { safe_join(texts, tag.br) }
    end
  end
end
