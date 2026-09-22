# frozen_string_literal: true

class Cron::DiscardedBrouillonDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 02:00'

  private

  # On the removal stage, a trashed brouillon is hidden and due at its purge.
  def scope = Dossier.removal_stage_read? ? Dossier.state_brouillon.removal_due(:hidden) : Dossier.en_brouillon_expired_to_delete
end
