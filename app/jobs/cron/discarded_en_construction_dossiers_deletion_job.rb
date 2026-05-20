# frozen_string_literal: true

class Cron::DiscardedEnConstructionDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 03:30'

  private

  def scope = Dossier.en_construction_expired_to_delete
end
