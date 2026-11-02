# frozen_string_literal: true

class ResetExpiringDossiersJob < ApplicationJob
  queue_as :low
  def perform(procedure)
    procedure
      .dossiers
      .in_batches do |relation|
      relation.each do |dossier|
        if dossier.expiration_started?
          hidden_by_expired = dossier.hidden_by_expired?
          reason = dossier.hidden_by_reason
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_expirant)
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_suppression) if hidden_by_expired
          dossier.transaction do
            updated = dossier.update(brouillon_close_to_expiration_notice_sent_at: nil,
                                     termine_close_to_expiration_notice_sent_at: nil,
                                     hidden_by_expired_at: nil)
            if updated && hidden_by_expired
              restored_to_administration = Dossier.visible_by_administration.exists?(dossier.id)
              dossier.publish_event(Events::DossierRestaureParAdministration, reason:, restored_to_administration:)
            end
          end
        end
        dossier.update_expired_at
      end
    end
  end
end
