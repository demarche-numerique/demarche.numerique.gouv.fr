# frozen_string_literal: true

class Cron::DiscardedBrouillonDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 02:00'

  private

  def scope = Dossier.en_brouillon_expired_to_delete
end
