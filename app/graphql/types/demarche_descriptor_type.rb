# frozen_string_literal: true

module Types
  class DemarcheDescriptorType < Types::BaseObject
    class FindDemarcheInput < Types::BaseInputObject
      one_of
      argument :number, Int, "Numero de la démarche.", required: false
      argument :id, ID, "ID de la démarche.", required: false
    end

    description "Une démarche (métadonnées)
Ceci est une version abrégée du type `Demarche`, qui n’expose que les métadonnées.
Cela évite l’accès récursif aux dossiers."

    global_id_field :id
    field :number, Int, "Numero de la démarche.", null: false
    field :title, String, "Titre de la démarche.", null: false
    field :description, String, "Description de la démarche.", null: false
    field :state, Types::DemarcheType::DemarcheState, "État de la démarche.", null: false
    field :declarative, Types::DemarcheType::DossierDeclarativeState, "Pour une démarche déclarative, état cible des dossiers à valider automatiquement", null: true
    field :for_individual, Boolean, null: false

    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true
    field :date_derniere_modification, GraphQL::Types::ISO8601DateTime, "Date de la dernière modification.", null: false
    field :date_depublication, GraphQL::Types::ISO8601DateTime, "Date de la dépublication.", null: true
    field :date_fermeture, GraphQL::Types::ISO8601DateTime, "Date de la fermeture.", null: true

    field :duree_conservation_dossiers, Int, "Durée de conservation des dossiers en mois.", null: false

    field :demarcheUrl, Types::URL, camelize: false, null: true, deprecation_reason: 'Utilisez le champ `demarcheURL` à la place.'
    field :siteWebUrl, String, camelize: false, null: true, deprecation_reason: 'Utilisez le champ `siteWebURL` à la place.'
    field :dpoUrl, String, camelize: false, null: true, deprecation_reason: 'Utilisez le champ `dpoURL` à la place.'
    field :noticeUrl, Types::URL, camelize: false, null: true, deprecation_reason: 'Utilisez le champ `noticeURL` à la place.'
    field :cadreJuridiqueUrl, String, camelize: false, null: true, deprecation_reason: 'Utilisez le champ `cadreJuridiqueURL` à la place.'

    field :demarcheURL, Types::URL, "URL pour commencer la démarche", null: true, camelize: false
    field :siteWebURL, String, "URL où les usagers trouvent le lien vers la démarche", null: true, camelize: false
    field :dpoURL, String, "URL ou adresse électronique pour contacter le Délégué à la Protection des Données (DPO)", null: true, camelize: false
    field :noticeURL, Types::URL, null: true, camelize: false
    field :cadreJuridiqueURL, String, "URL du cadre juridique qui justifie le droit de collecter les données demandées dans la démarche", null: true, camelize: false

    field :opendata, Boolean, null: false
    field :tags, [String], "mots ou expressions attribués à la démarche pour décrire son contenu et la retrouver", null: false
    field :zones, [String], "ministère(s) ou collectivité(s) qui mettent en oeuvre la démarche", null: false

    field :revision, Types::RevisionType, null: false
    field :service, Types::ServiceType, null: true

    field :logo, Types::File, null: true, extensions: [{ Extensions::Attachment => { root: :procedure } }]
    field :notice, Types::File, "notice explicative de la démarche", null: true, extensions: [{ Extensions::Attachment => { root: :procedure } }]
    field :deliberation, Types::File, "fichier contenant le cadre juridique", null: true, extensions: [{ Extensions::Attachment => { root: :procedure } }]

    field :dossiers_count, Int, "nb de dossiers déposés", null: false, internal: true

    def service
      Loaders::Association.for(procedure.class, :service).load(procedure)
    end

    def revision
      if object.is_a?(ProcedureRevision)
        object
      else
        object.active_revision
      end
    end

    def procedure
      if object.is_a?(ProcedureRevision)
        object.procedure
      else
        object
      end
    end

    def dossiers_count
      procedure.dossiers.visible_by_administration.count
    end

    def state
      procedure.aasm.current_state
    end

    delegate :description, :opendata, :tags, to: :procedure

    def demarche_url
      Rails.application.routes.url_helpers.commencer_url(path: procedure.path)
    end
    alias demarcheUrl demarche_url
    alias demarcheURL demarche_url

    def dpo_url
      procedure.lien_dpo
    end
    alias dpoUrl dpo_url
    alias dpoURL dpo_url

    def notice_url
      procedure.lien_notice
    end
    alias noticeUrl notice_url
    alias noticeURL notice_url

    def cadre_juridique_url
      procedure.cadre_juridique
    end
    alias cadreJuridiqueUrl cadre_juridique_url
    alias cadreJuridiqueURL cadre_juridique_url

    def site_web_url
      procedure.lien_site_web
    end
    alias siteWebUrl site_web_url
    alias siteWebURL site_web_url

    def number
      procedure.id
    end

    def title
      procedure.libelle
    end

    def declarative
      procedure.declarative_with_state
    end

    def for_individual
      procedure.for_individual
    end

    def date_creation
      procedure.created_at
    end

    def date_publication
      procedure.published_at
    end

    def date_derniere_modification
      procedure.updated_at
    end

    def date_depublication
      procedure.unpublished_at
    end

    def date_fermeture
      procedure.closed_at
    end

    def duree_conservation_dossiers
      procedure.duree_conservation_dossiers_dans_ds
    end

    def zones
      procedure.zones.map(&:current_label)
    end

    def self.authorized?(object, context)
      procedure = object.is_a?(ProcedureRevision) ? object.procedure : object
      context.authorized_demarche?(procedure, opendata: true)
    end
  end
end
