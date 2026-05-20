# frozen_string_literal: true

class Cron::DiscardedTermineDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 05:00'

  private

  def scope = Dossier.termine_expired_to_delete
end
