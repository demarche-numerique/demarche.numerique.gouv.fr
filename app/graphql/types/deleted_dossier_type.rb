# frozen_string_literal: true

module Types
  class DeletedDossierType < Types::BaseObject
    class DeletedDossierReasonType < Types::BaseEnum
      DeletedDossier.reasons.keys.each do |reason|
        value(reason, value: reason)
      end
    end

    description "Un dossier supprimé"

    global_id_field :id
    field :number, Int, "Le numéro du dossier qui a été supprimé.", null: false

    field :state, Types::DossierType::DossierState, "L’état du dossier supprimé.", null: false
    field :reason, DeletedDossierReasonType, "La raison de la suppression du dossier.", null: false

    field :date_supression, GraphQL::Types::ISO8601DateTime, "Date de suppression.", null: false

    def self.authorized?(object, context)
      context.authorized_demarche?(context.dataloader.with(Sources::Association, :procedure).load(object))
    end

    def date_supression
      if object.is_a?(Dossier)
        object.hidden_by_administration_at || object.hidden_by_user_at || object.hidden_by_expired_at
      else
        object.deleted_at
      end
    end

    def number
      if object.is_a?(Dossier)
        object.id
      else
        object.dossier_id
      end
    end

    def reason
      if object.is_a?(Dossier)
        # restore by the administration clears the reason but keeps an expired dossier hidden
        object.hidden_by_reason || ('expired' if object.hidden_by_expired?)
      else
        object.reason
      end
    end
  end
end
