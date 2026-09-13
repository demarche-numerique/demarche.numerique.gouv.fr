# frozen_string_literal: true

class SerializerService
  class Error < StandardError; end

  # Internal serialization (audit log, datagouv export) runs the public stored
  # queries so the recorded shape stays the one integrators see. File URLs are
  # transient signed links, so they are left out of what gets persisted.
  DOSSIER_VARIABLES = {
    includeChamps: true,
    includeAnnotations: true,
    includeTraitements: true,
    includeInstructeurs: true,
    includeAvis: true,
    includeFileUrls: false,
  }.freeze

  def self.dossier(dossier)
    tag_scope(dossier: dossier.id)

    data = execute_query('getDossier', DOSSIER_VARIABLES.merge(dossierNumber: dossier.id))
    data && data['dossier']
  end

  def self.demarches_publiques(after: nil)
    data = execute_query('getDemarcheDescriptors', { after:, includeRevision: true, includeService: true, includeFileUrls: false })
    data && data['demarcheDescriptors']
  end

  def self.avis(avis)
    data = execute_records_query(number: avis.dossier_id, avisId: avis.to_typed_id, includeAvis: true)
    data && data['dossier']['avis'].first
  end

  def self.champ(champ)
    tag_scope(dossier: champ.dossier_id, champ: champ.id)

    if champ.private?
      data = execute_records_query(number: champ.dossier_id, annotationId: champ.to_typed_id, includeAnnotations: true)
      data && data['dossier']['annotations'].first
    else
      data = execute_records_query(number: champ.dossier_id, champId: champ.to_typed_id, includeChamps: true)
      data && data['dossier']['champs'].first
    end
  end

  def self.message(commentaire)
    tag_scope(dossier: commentaire.dossier_id)

    data = execute_records_query(number: commentaire.dossier_id, messageId: commentaire.to_typed_id, includeMessages: true)
    data && data['dossier']["messages"].first
  end

  def self.execute_records_query(number:, **variables)
    execute_query('getDossierRecords', { dossierNumber: number, includeFileUrls: false, **variables })
  end

  def self.execute_query(operation_name, variables)
    result = API::V2::StoredQuery.execute('ds-query-v2',
      variables: variables.stringify_keys,
      context: { internal_use: true },
      operation_name: operation_name)
    if result['errors'].present?
      raise Error, result['errors'].first['message']
    end
    result['data']
  end

  # The tags go on the current scope, which sentry-rails and sentry-sidekiq reset
  # per request and per job: a failure raised out of here is reported once, by the
  # request or the job that fails on it, and still carries the record being
  # serialized. A capture in a with_scope block would report it a second time.
  def self.tag_scope(**tags)
    Sentry.set_tags(tags)
  end
end
