# frozen_string_literal: true

class APIEntreprise::EffectifsAdapter < APIEntreprise::Adapter
  def initialize(siret, procedure_id, annee, mois)
    @siret = siret
    @procedure_id = procedure_id
    @annee = annee
    @mois = mois
  end

  private

  def get_resource
    api(@procedure_id).effectifs(@siret, @annee, @mois)
  end

  def process_params
    data = data_source.fetch(:data, nil)
    Sentry.set_tags(siret: @siret)

    effectifs = data&.fetch(:effectifs_mensuels, nil)&.first
    if effectifs.present?
      {
        entreprise_effectif_mensuel: effectifs[:value],
        entreprise_effectif_mois: effectifs[:mois],
        entreprise_effectif_annee: effectifs[:annee],
      }
    else
      {}
    end
  end
end
