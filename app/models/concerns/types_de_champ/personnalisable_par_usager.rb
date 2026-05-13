# frozen_string_literal: true

module TypesDeChamp::PersonnalisableParUsager
  extend ActiveSupport::Concern

  AUTHORIZED_TYPE_CHAMPS = %w[
    text integer_number decimal_number formatted
    date datetime dossier_link
    drop_down_list multiple_drop_down_list linked_drop_down_list
    civilite email phone siret rna rnf annuaire_education iban
    address communes departements regions pays epci
  ].freeze

  included do
    scope :personnalisables_par_usager, -> {
      where(type_champ: AUTHORIZED_TYPE_CHAMPS)
    }
  end
end
