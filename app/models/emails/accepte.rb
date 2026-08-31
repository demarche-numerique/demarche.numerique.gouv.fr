# frozen_string_literal: true

module Emails
  class Accepte < EmailTemplate
    SLUG = "accepte"
    DEFAULT_TEMPLATE_NAME = "notification_mailer/default_templates/accepte"
    DISPLAYED_NAME = I18n.t('activerecord.models.email.accepte.acceptance_acknowledgment')
    DEFAULT_SUBJECT = I18n.t('activerecord.models.email.accepte.default_subject', dossier_number: '--numéro du dossier--', procedure_libelle: '--libellé démarche--')
    DOSSIER_STATE = Dossier.states.fetch(:accepte)

    def self.default_template_locals(procedure)
      { with_attestation: procedure.attestation_acceptation_template&.activated? }
    end
  end
end
