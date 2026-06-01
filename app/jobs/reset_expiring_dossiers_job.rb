# frozen_string_literal: true

class ResetExpiringDossiersJob < ApplicationJob
  queue_as :low
  def perform(procedure)
    procedure
      .dossiers
      .in_batches do |relation|
      relation.each do |dossier|
        if dossier.expiration_started?
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_expirant)
          DossierNotification.destroy_notifications_by_dossier_and_type(dossier, :dossier_suppression) if dossier.hidden_by_expired?
          dossier.update(brouillon_close_to_expiration_notice_sent_at: nil,
                        termine_close_to_expiration_notice_sent_at: nil,
                        hidden_by_expired_at: nil)
        end
        dossier.update_expired_at
      end
    end
  end
end
