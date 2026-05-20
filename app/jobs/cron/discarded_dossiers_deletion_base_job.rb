# frozen_string_literal: true

class Cron::DiscardedDossiersDeletionBaseJob < Cron::CronJob
  BATCH_LIMIT = 100

  def perform
    count = 0
    scope.find_each(batch_size: BATCH_LIMIT) do |dossier|
      dossier.purge_discarded
      count += 1

      if count >= BATCH_LIMIT
        self.class.perform_later if scope.exists?
        return
      end
    end
  end

  private

  def scope = raise NotImplementedError
end
