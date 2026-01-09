# frozen_string_literal: true

module Maintenance
  class T20250415removeMisplacedAutodestructionHeaderTask < MaintenanceTasks::Task
    # Un bug s’est glissé dans le DelayedPurgeJob : il supprime les fichiers sur le storage
    # OpenStack même si le blob est toujours attaché à un enregistrement.
    # C’est le cas par exemple des fichiers partagés entre dossiers ou procédures clonés.
    #
    # A partir des logs emis lors du dépot du flag x-delete-at, on ré́alise une liste de tous les
    # blob.key potentiellement concernés par ce bugs
    #
    # Le CSV doit contenir une seule colonne : blob_key et ne pas avoir de header.
    #
    # Pour chaque blob.key, on va :
    # - vérifier si le blob est attaché à un enregistrement
    # - vérifier si le blob existe toujours sur le storage
    # - vérifier si le blob est toujours marqué pour autodestruction
    # - si le blob est marqué pour autodestruction et toujours attaché,
    # on va le "sauver" retirant le flag
    # - on va par ailleurs logger dans la table TaskLog les blobs qui n’existent plus
    # sur le storage afin de de prévenir les utilisateurs

    csv_collection(headers: ['blob_key'])

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def process(row)
      blob_key = row['blob_key']

      blob = ActiveStorage::Blob.find_by(key: blob_key)

      # the blob does not exist anymore, we cannot link it to attachments
      # so we don't know if it was legitimately deleted or not
      if blob.nil?
        TaskLog.create!(data: { blob_key:, state: 'not present in db' })
        return
      end

      # the blob is not attached to anything, so it was legitimately deleted
      if blob.attachments.empty?
        TaskLog.create!(data: { blob_key:, state: 'legit deleted' })
        return
      end

      container, key = blob.service.container, blob.key

      found = true
      begin
        payload = client.head_object(container, key)
      rescue Fog::OpenStack::Storage::NotFound
        found = false
      end

      # the blob is already deleted, fuck
      # we gonna try to log as much as possible
      if !found
        blob.attachments.each do |attachment|
          name, record_type, record_id = attachment.name, attachment.record_type, attachment.record_id

          champ = (record_type == 'Champ') ? attachment.record : nil

          # sometime the attachment as no more record
          if champ.present?
            champ_libelle = begin
              attachment.record.libelle
                            # sometimes, a type de champ is found in the revision
                            rescue StandardError
                              ''
            end

            dossier_id = champ.dossier_id
            dossier_state = champ.dossier.state
            email = champ.dossier.user.email
            procedure = champ.dossier.procedure
            procedure_id, procedure_libelle = procedure.id, procedure.libelle

            TaskLog.create!(data: { blob_key:, dossier_id:, dossier_state:, champ_libelle:, procedure_id:, procedure_libelle:, email:, state: 'lost' })
          else
            TaskLog.create!(data: { blob_key:, record_type:, record_id:, name:, state: 'lost' })
          end
        end
        return
      end

      # the blob is not flagged for autodestruction, so don't worry
      if payload.headers['x-delete-at'].nil?
        TaskLog.create!(data: { blob_key:, state: 'not flagged' })
        return
      end

      # post on the object erase existing metadata (including x-delete-at)
      # we just need to set the content type
      client.post_object(container, key, { 'Content-Type' => blob.content_type })

      TaskLog.create!(data: { blob_key:, state: 'saved' })
    end

    def client
      ActiveStorage::Blob.service.send(:client)
    end
  end
end
