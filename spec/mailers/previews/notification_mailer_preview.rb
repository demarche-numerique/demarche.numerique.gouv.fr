# frozen_string_literal: true

class NotificationMailerPreview < ActionMailer::Preview
  def send_en_construction_notification
    NotificationMailer.send_en_construction_notification(dossier_with_image)
  end

  def send_en_instruction_notification
    NotificationMailer.send_en_instruction_notification(dossier)
  end

  def send_accepte_notification
    NotificationMailer.send_accepte_notification(dossier(:accepte))
  end

  def send_refuse_notification
    NotificationMailer.send_refuse_notification(dossier_with_motivation)
  end

  def send_sans_suite_notification
    NotificationMailer.send_sans_suite_notification(dossier)
  end

  def send_notification_for_tiers
    NotificationMailer.send_notification_for_tiers(dossier)
  end

  def send_accuse_lecture_notification
    NotificationMailer.send_accuse_lecture_notification(dossier)
  end

  private

  def dossier(state = nil)
    Dossier.where(state:).last || Dossier.last
  end

  def dossier_with_image
    Dossier.joins(procedure: [:initiated_mail]).where("initiated_mails.body like ?", "%<img%").order('RANDOM()').first
  end

  def dossier_with_motivation
    Dossier.last.tap { |d| d.assign_attributes(motivation: 'Le montant demandé dépasse le plafond autorisé') }
  end
end
