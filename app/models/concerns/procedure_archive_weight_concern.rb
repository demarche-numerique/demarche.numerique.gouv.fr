# frozen_string_literal: true

# Predicts the weight of a monthly archive before it is generated: the archives
# pages multiply the number of terminated dossiers of the month by the average
# weight of a dossier in an archive.
module ProcedureArchiveWeightConcern
  extend ActiveSupport::Concern

  include ExportedFilesSizeConcern

  # Enough dossiers for a stable mean, few enough to keep the queries cheap.
  ARCHIVE_WEIGHT_SAMPLE_SIZE = 100

  # The estimate is a slow-moving figure and its queries walk the attachments of
  # a hundred dossiers: one computation a day per procedure is plenty. When the
  # entry expires, one request recomputes it while the others keep the stale
  # value for a while, instead of every request recomputing at once.
  ARCHIVE_WEIGHT_CACHE_DURATION = 1.day
  ARCHIVE_WEIGHT_CACHE_GRACE = 1.minute

  # Cached in place of the weight when the procedure has no archivable dossier.
  # It is the case where the sample query walks the most rows for nothing (many
  # dossiers, none terminated), so it is the last one to recompute on every
  # page view; the archives page has no month to estimate then anyway.
  NO_ARCHIVABLE_DOSSIER = :none

  def average_dossier_weight
    weight = Rails.cache.fetch(['procedure', id, 'average_dossier_weight'], expires_in: ARCHIVE_WEIGHT_CACHE_DURATION, race_condition_ttl: ARCHIVE_WEIGHT_CACHE_GRACE) do
      compute_average_dossier_weight || NO_ARCHIVABLE_DOSSIER
    end

    weight unless weight == NO_ARCHIVABLE_DOSSIER
  end

  private

  def compute_average_dossier_weight
    # Any hundred archivable dossiers: an order would sort the whole population
    # of the procedure (no index carries processed_at, and the ones on
    # groupe_instructeur_id only order within one groupe), where the unordered
    # walk of the revision_id index stops at the hundredth row.
    dossier_ids = dossiers.archivable.limit(ARCHIVE_WEIGHT_SAMPLE_SIZE).ids
    return if dossier_ids.empty?

    exported_files_size(dossier_ids) / dossier_ids.size
  end
end
