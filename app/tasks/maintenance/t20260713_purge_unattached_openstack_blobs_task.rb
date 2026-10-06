# frozen_string_literal: true

module Maintenance
  class T20260713PurgeUnattachedOpenstackBlobsTask < MaintenanceTasks::Task
    # Reparcours de tout le stock de blobs (~120M) pour supprimer les orphelins
    # laissés en base : blobs sans attachment, leurs variants, et les fichiers
    # correspondants sur le bucket OpenStack.
    #
    # On itère par plage d'id (in_batches batche par clé primaire) en ne ciblant
    # que les blobs stockés sur openstack. Pour chaque lot, on isole les parents
    # réellement orphelins puis on délègue la purge à BlobService.
    #
    # Chaque blob supprimé est tracé (une ligne JSON) dans log/purge_unattached_
    # openstack_blobs.log, l'opération étant irréversible.
    #
    # Dépend du monkeypatch de delete_multiple_objects (config/initializers/
    # active_storage.rb, PR #13421).

    LOG_PATH = Rails.root.join('log', 'purge_unattached_openstack_blobs.log')

    def collection
      ActiveStorage::Blob.where(service_name: :openstack).in_batches(of: BlobService::BATCH_SIZE)
    end

    def process(batch)
      parent_ids = batch
        .unattached
        .where(soft_deleted_at: nil, created_at: ..1.day.ago).ids

      return if parent_ids.empty?

      BlobService.purge_blobs_with_variants(parent_ids) { logger.info(it.to_json) }
    end

    private

    def logger
      @logger ||= Logger.new(LOG_PATH)
    end
  end
end
