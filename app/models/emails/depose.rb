# frozen_string_literal: true

module Emails
  class Depose < EmailTemplate
    SLUG = "depose"
    DEFAULT_TEMPLATE_NAME = "notification_mailer/default_templates/depose"
    DISPLAYED_NAME = I18n.t('activerecord.models.email.depose.proof_of_receipt')
    DEFAULT_SUBJECT = I18n.t('activerecord.models.email.depose.default_subject', dossier_number: '--numéro du dossier--', procedure_libelle: '--libellé démarche--')
    DOSSIER_STATE = Dossier.states.fetch(:en_construction)

    def attachment_for_dossier(dossier)
      {
        filename: I18n.t('users.dossiers.show.attestation_depot.filename', dossier_id: dossier.id),
        content: dossier.generate_or_reuse_attestation_depot,
      }
    rescue TypstService::Error => e
      # The attestation is a nicety: never let its generation failure block
      # the depose notification email itself.
      Sentry.capture_exception(e, extra: { dossier_id: dossier.id })
      nil
    end
  end
end
