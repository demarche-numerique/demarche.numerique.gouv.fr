# frozen_string_literal: true

class NotificationMailerPreview < ActionMailer::Preview
  # Le bloc « Je donne mon avis » est identique quel que soit l'état : un seul aperçu suffit.
  JDMA_EMBED = '<a href="https://jedonnemonavis.numerique.gouv.fr/Demarches/123?nd_source=button&key=abc"><img src="https://jedonnemonavis.numerique.gouv.fr/static/bouton-bleu-clair.svg" alt="Je donne mon avis" /></a>'

  def send_depose_notification
    NotificationMailer.send_depose_notification(dossier_with_image)
  end

  def send_en_instruction_notification
    NotificationMailer.send_en_instruction_notification(dossier)
  end

  def send_accepte_notification
    NotificationMailer.send_accepte_notification(dossier(:accepte))
  end

  def send_accepte_notification_with_jdma
    NotificationMailer.send_accepte_notification(with_jdma(dossier(:accepte)))
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
    Dossier.joins(procedure: [:email_depose_templates]).where("email_templates.body like ?", "%<img%").order('RANDOM()').first
  end

  def dossier_with_motivation
    Dossier.last.tap { |d| d.assign_attributes(motivation: 'Le montant demandé dépasse le plafond autorisé') }
  end

  # Injecte un code JDMA en mémoire (pas d'écriture en base) sur un dossier réel.
  def with_jdma(dossier)
    dossier.tap { it.procedure.monavis_embed = JDMA_EMBED }
  end
end
