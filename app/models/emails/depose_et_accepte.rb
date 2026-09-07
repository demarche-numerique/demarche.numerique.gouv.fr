# frozen_string_literal: true

module Emails
  # Sent once, on the automatic acceptance of a declarative procedure: it
  # replaces the pair "accusé de réception" + "accusé d’acceptation".
  class DeposeEtAccepte < Depose
    DEFAULT_TEMPLATE_NAME = "notification_mailer/default_templates/depose_et_accepte"
    DISPLAYED_NAME = I18n.t('activerecord.models.email.depose_et_accepte.proof_of_receipt')
    DEFAULT_SUBJECT = I18n.t('activerecord.models.email.depose_et_accepte.default_subject', dossier_number: '--numéro du dossier--', procedure_libelle: '--libellé démarche--')
    DOSSIER_STATE = Dossier.states.fetch(:accepte)

    def self.default_template_locals(procedure)
      { with_attestation: procedure.attestation_acceptation_template&.activated? }
    end
  end
end
