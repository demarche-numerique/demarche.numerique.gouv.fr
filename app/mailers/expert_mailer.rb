# frozen_string_literal: true

class ExpertMailer < ApplicationMailer
  include RevokedExpertGuardConcern

  layout 'mailers/layout'

  def send_dossier_decision(avis)
    return if not_revoked_avis(avis).empty?

    @avis = avis
    @dossier = @avis.dossier
    email = @avis.expert.email
    @decision = decision_dossier(@dossier)
    subject = t('.subject', dossier_id: @dossier.id, decision: @decision, libelle: @dossier.procedure.libelle)

    mail(to: email, subject:)
  end

  # Compat shim consuming the delivery jobs enqueued under the old action name
  # before this rename was deployed. Remove once the Sidekiq retry set has
  # drained (~3 weeks, the default 25 retries of PriorizedMailDeliveryJob).
  def self.send_dossier_decision_v2(avis) = send_dossier_decision(avis)

  def self.critical_email?(action_name)
    false
  end

  private

  def decision_dossier(dossier)
    if dossier.accepte?
      t('users.dossiers.attestation_depot.states.accepte')
    elsif dossier.sans_suite?
      t('users.dossiers.attestation_depot.states.sans_suite')
    elsif dossier.refuse?
      t('users.dossiers.attestation_depot.states.refuse')
    end
  end
end
