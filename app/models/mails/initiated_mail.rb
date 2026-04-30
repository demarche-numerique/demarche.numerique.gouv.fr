# frozen_string_literal: true

# == Schema Information
#
# Table name: initiated_mails
#
#  id           :integer          not null, primary key
#  body         :text
#  subject      :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  procedure_id :integer
#
module Mails
  # en_construction
  class InitiatedMail < ApplicationRecord
    include MailTemplateConcern

    belongs_to :procedure, optional: false

    validates :subject, tags: true
    validates :body, tags: true

    SLUG = "initiated_mail"
    DEFAULT_TEMPLATE_NAME = "notification_mailer/default_templates/initiated_mail"
    DISPLAYED_NAME = I18n.t('activerecord.models.mail.initiated_mail.proof_of_receipt')
    DEFAULT_SUBJECT = I18n.t('activerecord.models.mail.initiated_mail.default_subject', dossier_number: '--numéro du dossier--', procedure_libelle: '--libellé démarche--')
    DOSSIER_STATE = Dossier.states.fetch(:en_construction)

    def attachment_for_dossier(dossier)
      {
        filename: I18n.t('users.dossiers.show.attestation_depot.filename', dossier_id: dossier.id),
        content: dossier.generate_or_reuse_attestation_depot,
      }
    end
  end
end
