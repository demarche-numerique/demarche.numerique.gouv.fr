# frozen_string_literal: true

module Maintenance
  class T20260427backfillVirusScanBlobsTask < MaintenanceTasks::Task
    # Traite le stock de blobs bloqués en virus_scan_result "pending".
    # Le CRON FixMissingAntivirusAnalysisJob gère le flux (blobs récents),
    # cette tâche gère le stock (backlog ancien).
    #
    # Inclut les orphelins (sans attachment) : BlobProcessorJob les marquera
    # simplement comme processed, et PurgeUnattachedBlobsJob les purgera.
    # On évite ainsi le semi-join sur 103M attachments qui timeout.
    #
    # On itère via Blob.in_batches (sans filtre WHERE) puis on applique le
    # filtre virus_scan_result dans process() sur le batch déjà borné par
    # ids. Itérer directement sur where(virus_scan_result: PENDING) timeout :
    # avec ~7M lignes pending sur 100M, le cursor `ORDER BY id LIMIT N`
    # avec ce filtre est trop coûteux si les pending sont concentrés sur
    # une plage d'ids (PG parcourt l'index PK en filtrant et peut traverser
    # des dizaines de millions de lignes avant d'en trouver N).

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      ActiveStorage::Blob.in_batches(of: 10_000)
    end

    def process(batch)
      batch
        .where(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
        .find_each do |blob|
          next if blob.metadata["processed"]

          BlobProcessorJob.perform_later(blob)
        end
    end
  end
end
