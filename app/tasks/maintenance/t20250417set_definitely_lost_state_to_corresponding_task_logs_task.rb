# frozen_string_literal: true

module Maintenance
  class T20250417setDefinitelyLostStateToCorrespondingTaskLogsTask < MaintenanceTasks::Task
    # Ce script est utilisé pour mettre à jour l’état des TaskLogs
    # correspondant aux blobs qui ont été supprimés et qui n’ont pas pu être récupérés
    # depuis le backup.

    csv_collection(headers: ['blob_key'])

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    def process(row)
      blob_key = row['blob_key']

      blob = ActiveStorage::Blob.find_by(key: blob_key)

      if blob.nil?
        TaskLog.where("data->>'blob_key' = ?", blob_key)
          .update_all(%(data = jsonb_set(data, '{state}', '"not present in db"')))
      else
        TaskLog.where("data->>'blob_key' = ?", blob_key)
          .update_all(%(data = jsonb_set(data, '{state}', '"definitely lost"')))
      end
    end
  end
end
