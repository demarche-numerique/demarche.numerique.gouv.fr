# frozen_string_literal: true

module Types
  class DemarcheType < Types::BaseObject
    class DemarcheState < Types::BaseEnum
      Procedure.aasm.states.reject { |state| state.name == :hidden }.each do |state|
        value(state.name.to_s,
            I18n.t(state, scope: [:activerecord, :attributes, :procedure, :api_state]),
           value: state.name)
      end
    end

    class DossierDeclarativeState < Types::BaseEnum
      Procedure.declarative_with_states.each do |symbol_name, string_name|
        value(string_name,
          I18n.t("declarative_with_state/#{string_name}", scope: [:activerecord, :attributes, :procedure]),
          value: symbol_name)
      end
    end

    description "Une démarche"

    global_id_field :id
    field :number, Int, "Numero de la démarche.", null: false, method: :id
    field :title, String, "Titre de la démarche.", null: false, method: :libelle
    field :description, String, "Description de la démarche.", null: false
    field :state, DemarcheState, "État de la démarche.", null: false
    field :declarative, DossierDeclarativeState, "Pour une démarche déclarative, état cible des dossiers à valider automatiquement", null: true, method: :declarative_with_state

    field :date_creation, GraphQL::Types::ISO8601DateTime, "Date de la création.", null: false, method: :created_at
    field :date_publication, GraphQL::Types::ISO8601DateTime, "Date de la publication.", null: true, method: :published_at
    field :date_derniere_modification, GraphQL::Types::ISO8601DateTime, "Date de la dernière modification.", null: false, method: :updated_at
    field :date_depublication, GraphQL::Types::ISO8601DateTime, "Date de la dépublication.", null: true, method: :unpublished_at
    field :date_fermeture, GraphQL::Types::ISO8601DateTime, "Date de la fermeture.", null: true, method: :closed_at

    field :groupe_instructeurs, [Types::GroupeInstructeurType], null: false do
      argument :closed, Boolean, required: false
    end
    field :service, Types::ServiceType, null: true

    field :dossiers, Types::DossierType.connection_type, "Liste de tous les dossiers d’une démarche.", null: false, extras: [:lookahead] do
      argument :order, Types::Order, default_value: :asc, required: false, description: "L’ordre des dossiers.", deprecation_reason: 'Utilisez l’argument `last` à la place.'
      argument :created_since, GraphQL::Types::ISO8601DateTime, required: false, description: "Dossiers déposés depuis la date."
      argument :updated_since, GraphQL::Types::ISO8601DateTime, required: false, description: "Dossiers mis à jour depuis la date."
      argument :state, Types::DossierType::DossierState, required: false, description: "Dossiers avec statut."
      argument :archived, Boolean, required: false, description: "Seulement les dossiers à archiver."
      argument :revision, ID, required: false, description: "Seulement les dossiers pour la révision donnée."
      argument :max_revision, ID, required: false, description: "Seulement les dossiers pour les révisons avant la révision donnée."
      argument :min_revision, ID, required: false, description: "Seulement les dossiers pour les révisons après la révision donnée."
    end

    field :deleted_dossiers, Types::DeletedDossierType.connection_type, "Liste de tous les dossiers supprimés d’une démarche.", null: false do
      argument :order, Types::Order, default_value: :asc, required: false, description: "L’ordre des dossiers supprimés.", deprecation_reason: 'Utilisez l’argument `last` à la place.'
      argument :deleted_since, GraphQL::Types::ISO8601DateTime, required: false, description: "Dossiers supprimés depuis la date."
    end
    field :pending_deleted_dossiers, Types::DeletedDossierType.connection_type, "Liste de tous les dossiers en attente de suppression définitive d’une démarche.", null: false do
      argument :order, Types::Order, default_value: :asc, required: false, description: "L’ordre des dossiers en attente de suppression.", deprecation_reason: 'Utilisez l’argument `last` à la place.'
      argument :deleted_since, GraphQL::Types::ISO8601DateTime, required: false, description: "Dossiers en attente de suppression depuis la date."
    end

    field :champ_descriptors, [Types::ChampDescriptorType], null: false, deprecation_reason: 'Utilisez le champ `activeRevision.champDescriptors` à la place.'
    field :annotation_descriptors, [Types::ChampDescriptorType], null: false, deprecation_reason: 'Utilisez le champ `activeRevision.annotationDescriptors` à la place.'

    field :active_revision, Types::RevisionType, null: false
    field :draft_revision, Types::RevisionType, null: false
    field :published_revision, Types::RevisionType, null: true
    field :revisions, [Types::RevisionType], null: false
    field :chorus_configuration, Types::ChorusConfigurationType, null: true, description: "Cadre budgétaire Chorus"
    field :labels, [Types::LabelType], null: false, description: 'Liste des labels associables aux dossiers'
    field :administrateurs, [Types::ProfileType], null: false, description: "Liste les administrateurs de la démarche"

    def state
      object.aasm.current_state
    end

    def groupe_instructeurs(closed: nil)
      if closed.nil?
        dataloader.with(Sources::Association, groupe_instructeurs: { procedure: [:administrateurs] }).load(object)
      elsif closed.true?
        dataloader.with(Sources::Association, active_groupe_instructeurs: { procedure: [:administrateurs] }).load(object)
      else
        dataloader.with(Sources::Association, closed_groupe_instructeurs: { procedure: [:administrateurs] }).load(object)
      end
    end

    def service
      dataloader.with(Sources::Association, :service).load(object)
    end

    def revisions
      dataloader.with(Sources::Association, :revisions).load(object)
    end

    def dossiers(updated_since: nil, created_since: nil, state: nil, archived: nil, revision: nil, max_revision: nil, min_revision: nil, order:, lookahead:)
      dossiers = object
        .dossiers
        .visible_by_administration
        .for_api_v2

      if state.present?
        dossiers = dossiers.where(state: state)
      end

      if !archived.nil?
        dossiers = dossiers.where(archived: archived)
      end

      if !revision.nil?
        dossiers = dossiers.where(revision: find_revision(revision))
      else
        if !min_revision.nil?
          dossiers = dossiers.joins(:revision).where(procedure_revisions: { created_at: find_revision(min_revision).created_at.. })
        end

        if !max_revision.nil?
          dossiers = dossiers.joins(:revision).where(procedure_revisions: { created_at: ..find_revision(max_revision).created_at })
        end
      end

      if updated_since.present?
        dossiers = dossiers.updated_since(updated_since)
      else
        if created_since.present?
          dossiers = dossiers.created_since(created_since)
        end
      end

      # We wrap dossiers in a custom connection alongsite the lookahead for the query.
      # The custom connection is responsible for preloading paginated dossiers.
      # https://graphql-ruby.org/pagination/custom_connections.html#using-a-custom-connection
      # https://graphql-ruby.org/queries/lookahead.html
      Connections::DossiersConnection.new(dossiers, lookahead: lookahead, deprecated_order: order)
    end

    def deleted_dossiers(deleted_since: nil, order:)
      dossiers = object.deleted_dossiers

      if deleted_since.present?
        dossiers = dossiers.deleted_since(deleted_since)
      end

      Connections::DeletedDossiersConnection.new(dossiers, deprecated_order: order)
    end

    def pending_deleted_dossiers(deleted_since: nil, order:)
      dossiers = object.dossiers.hidden_for_administration

      if deleted_since.present?
        dossiers = dossiers.hidden_since(deleted_since)
      end

      Connections::PendingDeletedDossiersConnection.new(dossiers, deprecated_order: order)
    end

    def champ_descriptors
      object.active_revision.public_revision_type_de_champs
    end

    def annotation_descriptors
      object.active_revision.private_revision_type_de_champs
    end

    def self.authorized?(object, context)
      context.authorized_demarche?(object)
    end

    private

    def find_revision(revision)
      revision_id = GraphQL::Schema::UniqueWithinType.decode(revision).second
      object.revisions.find(revision_id)
    end
  end
end
