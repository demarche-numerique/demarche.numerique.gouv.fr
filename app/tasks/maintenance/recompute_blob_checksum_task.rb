# frozen_string_literal: true

module Maintenance
  class RecomputeBlobChecksumTask < MaintenanceTasks::Task
    # Avant février 2024, les filigranes ont corrompu les hash des fichiers.
    # Régulièrement, des dossiers en brouillon étaient déposés avec ce problème
    # (on retrouve les fichiers corrompu dans l’onglet retry de sidekiq).
    # Cette tache recalcule les hashes.
    # 2024-05-27-01
    attribute :blob_ids, :string
    validates :blob_ids, presence: true

    def collection
      ids = blob_ids.split(',').map(&:strip).map(&:to_i)
      ActiveStorage::Blob.where(id: ids)
    end

    def process(blob)
      blob.upload(StringIO.new(blob.download), identify: false)
      blob.save!
    end

    def count
      # Optionally, define the number of rows that will be iterated over
      # This is used to track the task's progress
    end
  end
end
