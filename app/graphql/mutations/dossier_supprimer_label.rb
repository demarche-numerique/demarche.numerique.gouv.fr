# frozen_string_literal: true

module Mutations
  class DossierSupprimerLabel < Mutations::BaseMutation
    description "Supprimer un label d’un dossier"

    argument :dossier_id, ID, required: true, loads: Types::DossierType
    argument :label_id, ID, required: true, loads: Types::LabelType
    argument :instructeur_id, ID, "Instructeur qui retire le label.", required: false, loads: Types::ProfileType

    field :dossier, Types::DossierType, null: true
    field :label, Types::LabelType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, label:, instructeur: nil)
      dossier_label = dossier.remove_label(label, author: instructeur)

      if dossier_label&.destroyed?
        { dossier:, label: }
      else
        { errors: ['Impossible de supprimer le label'] }
      end
    end

    def authorized?(dossier:, label:, instructeur: nil, **_args)
      if dossier.labels.exclude?(label)
        [false, { errors: ["Ce label n’est pas associé au dossier"] }]
      elsif instructeur.present?
        dossier_authorized_for?(dossier, instructeur)
      else
        true
      end
    end
  end
end
