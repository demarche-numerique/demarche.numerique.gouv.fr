# frozen_string_literal: true

module Mutations
  class DossierSupprimerLabel < Mutations::BaseMutation
    description "Supprimer un label d’un dossier"

    argument :dossier_id, ID, required: true, loads: Types::DossierType
    argument :label_id, ID, required: true, loads: Types::LabelType

    field :dossier, Types::DossierType, null: true
    field :label, Types::LabelType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, label:)
      dossier_label = dossier.dossier_labels.find_by(label: label)

      if dossier_label.destroy
        { dossier:, label: }
      else
        { errors: ['Impossible de supprimer le label'] }
      end
    end

    def authorized?(dossier:, label:, **_args)
      if dossier.labels.exclude?(label)
        [false, { errors: ["Ce label n’est pas associé au dossier"] }]
      else
        true
      end
    end
  end
end
