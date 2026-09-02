# frozen_string_literal: true

# Payload of the attestation de depot (lib/typst/root/attestation_depot.typ):
# the letterhead, the requester, dossier and service sections, the date and
# the signature.
class Typst::AttestationDepotPayload < Typst::Payload
  attr_reader :dossier

  def initialize(dossier)
    super()
    @dossier = dossier
  end

  # i18n-tasks-use t('users.dossiers.attestation_depot.receipt')
  # i18n-tasks-use t('users.dossiers.attestation_depot.description')
  # i18n-tasks-use t('users.dossiers.attestation_depot.generated_at')
  # i18n-tasks-use t('users.dossiers.attestation_depot.signature')
  def to_h
    scope = 'users.dossiers.attestation_depot'

    {
      lang: I18n.locale.to_s,
      title: I18n.t(:receipt, scope:),
      procedure: dossier.procedure.libelle,
      description: I18n.t(
        :description,
        scope:,
        user_name: helpers.attestation_depot_requester_identity(dossier),
        procedure: dossier.procedure.libelle,
        date: I18n.l(dossier.depose_at, format: '%e %B %Y')
      ),
      date: I18n.t(:generated_at, scope:, date: I18n.l(Time.zone.today, format: :long)),
      **TypstService.letterhead,
      sections: [identity_section, dossier_section, service_section].compact,
      signature: I18n.t(:signature, scope:, app_name: APPLICATION_NAME),
    }
  end

  private

  def helpers = ApplicationController.helpers

  def identity_section
    rows = []

    if dossier.individual.present?
      rows << [Individual.human_attribute_name(:prenom), dossier.individual.prenom]
      rows << [Individual.human_attribute_name(:nom), dossier.individual.nom.upcase]
    end

    if dossier.etablissement.present?
      rows << [Etablissement.human_attribute_name(:denomination), helpers.raison_sociale_or_name(dossier.etablissement)]
      rows << [Etablissement.human_attribute_name(:siret), dossier.etablissement.siret]
    end

    return if rows.empty?

    rows << [User.human_attribute_name(:email), dossier.user_email_for(:display)]
    { title: I18n.t('views.shared.dossiers.demande.requester_identity'), rows: }
  end

  def dossier_section
    {
      title: Dossier.model_name.human,
      rows: [
        [Dossier.human_attribute_name(:id), dossier.id.to_s],
        [I18n.t('users.dossiers.attestation_depot.file_submitted_at'), I18n.l(dossier.depose_at, format: '%e %B %Y')],
        [I18n.t('users.dossiers.attestation_depot.dossier_state'), helpers.attestation_depot_dossier_state(dossier)],
      ],
    }
  end

  def service_section
    service = dossier.service_or_contact_information
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
