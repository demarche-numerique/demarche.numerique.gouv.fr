# frozen_string_literal: true

class APIEntreprise::ExercicesJob < APIEntreprise::Job
  def perform(etablissement_id, procedure_id)
    find_etablissement(etablissement_id)
    return if !etablissement.exercices_fetchable?

    with_adapter(APIEntreprise::ExercicesAdapter.new(etablissement.siret, procedure_id)) do |params|
      etablissement.update!(params)
    end
  end
end
