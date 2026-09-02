# frozen_string_literal: true

# Payload of the attestation de depot PDF (lib/typst/attestation_depot.typ,
# rendered by TypstService): already-localized strings only - Typst renders
# them as literal text, layout stays in the template and theme.
module DossierAttestationDepotConcern
  extend ActiveSupport::Concern

  # i18n-tasks-use t('users.dossiers.attestation_depot.receipt')
  # i18n-tasks-use t('users.dossiers.attestation_depot.description')
  # i18n-tasks-use t('users.dossiers.attestation_depot.generated_at')
  # i18n-tasks-use t('users.dossiers.attestation_depot.signature')
  def attestation_depot_typst_data
    helpers = ApplicationController.helpers
    scope = 'users.dossiers.attestation_depot'

    {
      lang: I18n.locale.to_s,
      title: I18n.t(:receipt, scope:),
      procedure: procedure.libelle,
      description: I18n.t(
        :description,
        scope:,
        user_name: helpers.attestation_depot_requester_identity(self),
        procedure: procedure.libelle,
        date: I18n.l(depose_at, format: '%e %B %Y')
      ),
      date: I18n.t(:generated_at, scope:, date: I18n.l(Time.zone.today, format: :long)),
      **TypstService.letterhead,
      sections: [
        attestation_depot_identity_section,
        attestation_depot_dossier_section,
        attestation_depot_service_section,
      ].compact,
      signature: I18n.t(:signature, scope:, app_name: APPLICATION_NAME),
    }
  end

  private

  def attestation_depot_identity_section
    rows = []

    if individual.present?
      rows << [Individual.human_attribute_name(:prenom), individual.prenom]
      rows << [Individual.human_attribute_name(:nom), individual.nom.upcase]
    end

    if etablissement.present?
      rows << [Etablissement.human_attribute_name(:denomination), ApplicationController.helpers.raison_sociale_or_name(etablissement)]
      rows << [Etablissement.human_attribute_name(:siret), etablissement.siret]
    end

    return if rows.empty?

    rows << [User.human_attribute_name(:email), user_email_for(:display)]
    { title: I18n.t('views.shared.dossiers.demande.requester_identity'), rows: }
  end

  def attestation_depot_dossier_section
    {
      title: Dossier.model_name.human,
      rows: [
        [Dossier.human_attribute_name(:id), id.to_s],
        [I18n.t('users.dossiers.attestation_depot.file_submitted_at'), I18n.l(depose_at, format: '%e %B %Y')],
        [I18n.t('users.dossiers.attestation_depot.dossier_state'), ApplicationController.helpers.attestation_depot_dossier_state(self)],
      ],
    }
  end

  def attestation_depot_service_section
    service = service_or_contact_information
    return if service.blank?

    rows = [
      [Service.model_name.human, service.pretty_nom],
      [Service.human_attribute_name(:adresse), service.adresse],
    ]
    rows << [Service.human_attribute_name(:email), service.email] if service.email.present?
    rows << [Service.human_attribute_name(:telephone), service.telephone] if service.telephone.present?

    { title: I18n.t('users.dossiers.attestation_depot.administrative_service'), rows: }
  end
end
