# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :demarche, DemarcheType, null: false, description: "Informations concernant une démarche." do
      argument :number, Int, "Numéro de la démarche.", required: true
    end

    field :dossier, DossierType, null: false, description: "Informations sur un dossier d’une démarche." do
      argument :number, Int, "Numéro du dossier.", required: true
    end

    field :groupe_instructeur, GroupeInstructeurWithDossiersType, null: false, description: "Informations sur un groupe instructeur." do
      argument :number, Int, "Numéro du groupe instructeur.", required: true
    end

    field :demarche_descriptor, DemarcheDescriptorType, null: true do
      argument :demarche, DemarcheDescriptorType::FindDemarcheInput, "La démarche.", required: true
    end

    field :demarches_publiques, DemarcheDescriptorType.connection_type, null: false, internal: true

    def demarches_publiques
      Procedure.publiques.includes(draft_revision: :procedure, published_revision: :procedure).with_attached_logo.with_attached_notice.with_attached_deliberation
    end

    def demarche_descriptor(demarche:)
      demarche_number = demarche.number.presence || ApplicationRecord.id_from_typed_id(demarche.id)
      Procedure
        .includes(draft_revision: :procedure, published_revision: :procedure)
        .find(demarche_number)
    end

    def demarche(number:)
      Procedure.for_api_v2.find(number)
    end

    def dossier(number:)
      dossier = if context.internal_use?
        Dossier.state_not_brouillon.for_api_v2.find(number)
      else
        Dossier.visible_by_administration.for_api_v2.find(number)
      end
      dossier.with_champs
    end

    def groupe_instructeur(number:)
      GroupeInstructeur.for_api_v2.find(number)
    end

    def self.accessible?(context)
      context[:token] || context[:administrateur_id]
    end
  end
end
