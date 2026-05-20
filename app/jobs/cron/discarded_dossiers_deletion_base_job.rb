# frozen_string_literal: true

class Cron::DiscardedDossiersDeletionBaseJob < Cron::CronJob
  BATCH_LIMIT = 100

  # Classe abstraite : empêche `rake jobs:schedule` de tenter d'enregistrer
  # cette base (qui n'a pas de schedule_expression) dans Sidekiq Cron.
  # Les sous-classes concrètes héritent : elles sont schedulable dès que
  # schedule_expression est défini.
  def self.schedulable?
    schedule_expression.present? && super
  end

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
