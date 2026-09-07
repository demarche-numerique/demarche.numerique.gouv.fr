# frozen_string_literal: true

module Emails
  # Sent once, on the automatic transition to en_instruction of a declarative
  # procedure: it replaces the pair "accusé de réception" + "passage en
  # instruction".
  class DeposeEtPasseEnInstruction < Depose
    DEFAULT_TEMPLATE_NAME = "notification_mailer/default_templates/depose_et_passe_en_instruction"
    DISPLAYED_NAME = I18n.t('activerecord.models.email.depose_et_passe_en_instruction.proof_of_receipt')
    DEFAULT_SUBJECT = I18n.t('activerecord.models.email.depose_et_passe_en_instruction.default_subject', dossier_number: '--numéro du dossier--', procedure_libelle: '--libellé démarche--')
    DOSSIER_STATE = Dossier.states.fetch(:en_instruction)
  end
end
