# frozen_string_literal: true

class Cron::DiscardedBrouillonDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 02:00'

  private

  def scope = Dossier.trash_purge_due
end
