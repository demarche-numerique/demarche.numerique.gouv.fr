# frozen_string_literal: true

module Mutations
  class DemarcheCloner < Mutations::BaseMutation
    description "Cloner une démarche."

    argument :demarche, Types::DemarcheDescriptorType::FindDemarcheInput, "La démarche", required: true
    argument :title, String, "Le titre de la nouvelle démarche.", required: false
    argument :clone_service, Boolean, "Cloner le service de la démarche.", required: false

    field :demarche, Types::DemarcheDescriptorType, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(demarche:, title: nil, clone_service: nil)
      demarche_number = demarche.number.presence || ApplicationRecord.id_from_typed_id(demarche.id)
      demarche = Procedure.with_active_revision.find_by(id: demarche_number)

      if demarche.present? && (demarche.opendata? || context.authorized_demarche?(demarche))
        cloned_demarche = demarche.clone(admin: context.current_administrateur, options: { clone_service: })
        cloned_demarche.update!(libelle: title) if title.present?
        context.authorize_demarche!(cloned_demarche)

        { demarche: cloned_demarche.draft_revision }
      else
        { errors: ["La démarche \"#{demarche_number}\" ne peut pas être clonée."] }
      end
    end
  end
end
