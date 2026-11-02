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
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_expirant)
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_suppression) if hidden_by_expired
          dossier.update(brouillon_close_to_expiration_notice_sent_at: nil,
                        termine_close_to_expiration_notice_sent_at: nil,
                        hidden_by_expired_at: nil)
          # the expiration emitted dossier_supprime
          if hidden_by_expired && Dossier.visible_by_administration.exists?(dossier.id)
            dossier.emit_webhook_event(:dossier_restaure)
          end
        end
        dossier.update_expired_at
      end
    end
  end
end
