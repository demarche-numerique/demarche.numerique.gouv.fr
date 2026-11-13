# frozen_string_literal: true

module Mutations
  class DossierAjouterLabel < Mutations::BaseMutation
    description "Ajouter un label à un dossier"

    argument :dossier_id, ID, required: true, loads: Types::DossierType
    argument :label_id, ID, "ID du label", required: true, loads: Types::LabelType

    field :dossier, Types::DossierType, null: true
    field :label, Types::LabelType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, label:)
      dossier_label = dossier.add_label(label)

      if dossier_label.persisted?
        { dossier:, label: }
      else
        { errors: dossier_label.errors.full_messages }
      end
    end

    def authorized?(dossier:, label:, **_args)
      if dossier.labels.include?(label)
        [false, { errors: ["Ce label est déjà associé au dossier"] }]
      elsif dossier.procedure != label.procedure
        [false, { errors: ["Ce label n’appartient pas à la même démarche que le dossier"] }]
      else
        true
      end
    end
  end
end
