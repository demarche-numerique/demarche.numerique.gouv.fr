# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include DemarcheAuthorizationConcern

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

    field :demarche_descriptors, DemarcheDescriptorType.connection_type, null: false, description: "Liste des démarches publiques (publiées ou closes, en opendata)."

    field :webhooks, [WebhookType], null: false, description: "Liste des webhooks d’une démarche." do
      argument :demarche, DemarcheDescriptorType::FindDemarcheInput, "La démarche.", required: true
    end

    field :webhook, WebhookType, null: false, description: "Informations sur un webhook." do
      argument :id, ID, "Identifiant du webhook.", required: true, loads: Types::WebhookType, as: :webhook
    end

    def demarche_descriptors
      Procedure.publiques.includes(
        :procedure_paths,
        published_revision: {
          revision_type_de_champs: :type_de_champ,
        }
      )
    end

    def demarche_descriptor(demarche:)
      Procedure
        .includes(:procedure_paths, draft_revision: :procedure, published_revision: :procedure)
        .find(demarche_number(demarche))
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

    def webhooks(demarche:)
      procedure = find_authorized_demarche(demarche)

      if procedure.nil?
        raise GraphQL::ExecutionError.new("La démarche \"#{demarche_number(demarche)}\" n'existe pas ou vous n'avez pas le droit d'y accéder.", extensions: { code: :unauthorized })
      end

      procedure.webhooks.order(:id)
    end

    def webhook(webhook:)
      webhook
    end

    def self.accessible?(context)
      context[:token] || context[:administrateur_id]
    end
  end
end
