# frozen_string_literal: true

module AvisNotificationConcern
  extend ActiveSupport::Concern

  def notify_other_experts
    return if confidentiel?

    other_experts_avis.each { AvisMailer.notify_new_avis_to_expert(it).deliver_later }
  end

  private

  # One avis per other expert: the mail links to the recipient's own avis.
  def other_experts_avis
    dossier.avis
      .not_revoked
      .where.not(experts_procedure_id:)
      .to_a
      .uniq(&:experts_procedure_id)
  end
end
