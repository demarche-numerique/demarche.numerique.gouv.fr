# frozen_string_literal: true

class Cron::DiscardedBrouillonDossiersDeletionJob < Cron::DiscardedDossiersDeletionBaseJob
  self.schedule_expression = 'every day at 02:00'

  private

  # A trashed brouillon is hidden and due at its purge.
  def scope = Dossier.state_brouillon.removal_due(:hidden)
end
