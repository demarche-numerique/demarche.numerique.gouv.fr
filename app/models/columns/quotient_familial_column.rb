# frozen_string_literal: true

class Columns::QuotientFamilialColumn < Columns::JSONPathColumn
  QUOTIENT_FAMILIAL_COLUMNS = [
    ['[Allocataire 1] Nom de naissance', '$.allocataires[0].nom_naissance'],
    ['[Allocataire 1] Prénoms', '$.allocataires[0].prenoms'],
    ['[Allocataire 2] Nom de naissance', '$.allocataires[1].nom_naissance'],
    ['[Allocataire 2] Prénoms', '$.allocataires[1].prenoms'],
    ['Valeur du QF', '$.quotient_familial.valeur'],
    ['Mois du QF', '$.quotient_familial.mois'],
    ['Année du QF', '$.quotient_familial.annee'],
  ]

  private

  def typed_value(champ)
    return super if champ.fc_data_correct?
  end
end
