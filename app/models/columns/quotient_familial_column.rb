# frozen_string_literal: true

class Columns::QuotientFamilialColumn < Columns::JSONPathColumn
  QUOTIENT_FAMILIAL_COLUMNS = [
    ['[Allocataire 1] Nom de naissance', '$.api_part.allocataires[0].nom_naissance', :text],
    ['[Allocataire 1] Prénoms', '$.api_part.allocataires[0].prenoms', :text],
    ['[Allocataire 2] Nom de naissance', '$.api_part.allocataires[1].nom_naissance', :text],
    ['[Allocataire 2] Prénoms', '$.api_part.allocataires[1].prenoms', :text],
    ['Valeur du QF', '$.api_part.quotient_familial.valeur', :integer],
    ['Période du QF', '$.api_part.quotient_familial.periode_effective', :date],
  ]

  def targeted_dossiers(dossiers, condition)
    super(dossiers, condition).where(champs: { value: 'true' })
  end

  private

  # Mirrors Champs::QuotientFamilialChamp#fc_data_correct?: the fetched data
  # only counts once approved by the user (`value` stores the approval flag).
  def typed_value(champ_data)
    return super if champ_data.fetched? && ActiveModel::Type::Boolean.new.cast(champ_data.value)
  end
end
