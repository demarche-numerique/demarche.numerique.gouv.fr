# frozen_string_literal: true

class APIEntreprise::EffectifsAnnuelsAdapter < APIEntreprise::Adapter
  def initialize(siret, procedure_id, year = default_year)
    @siret = siret
    @procedure_id = procedure_id
    @year = year
  end

  private

  def default_year
    Date.current.year - 1
  end

  def get_resource
    api(@procedure_id).effectifs_annuels(siren, @year)
  end

  def process_params
    data = data_source.fetch(:data, nil)
    Sentry.set_tags(siret: @siret)

    effectifs = data&.fetch(:effectifs_annuel, nil)&.first
    if effectifs.present?
      {
        entreprise_effectif_annuel: effectifs[:value],
        entreprise_effectif_annuel_annee: data[:annee],
      }
    else
      {}
    end
  end
end
