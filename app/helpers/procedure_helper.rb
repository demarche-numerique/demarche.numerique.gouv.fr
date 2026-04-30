# frozen_string_literal: true

module ProcedureHelper
  def procedure_libelle_with_number(procedure)
    "#{procedure.libelle} - n°#{procedure.id} "
  end

  def procedure_badge(procedure, alignment_class = '')
    if procedure.close? || procedure.depubliee? || procedure.brouillon?
      tag.span(t("activerecord.attributes.procedure.aasm_state.#{procedure.aasm_state}"), class: "fr-badge fr-badge--sm #{alignment_class}")
    end
  end

  def procedure_badge_class(procedure)
    if procedure.brouillon?
      'fr-badge--new'
    elsif procedure.publiee?
      'fr-badge--success'
    elsif procedure.close?
      'fr-badge--error'
    else
      'fr-badge--warning'
    end
  end

  def procedure_publish_label(procedure, key)
    # i18n-tasks-use t('modal.publish.body.publish')
    # i18n-tasks-use t('modal.publish.body.reopen')
    # i18n-tasks-use t('modal.publish.submit.publish')
    # i18n-tasks-use t('modal.publish.submit.reopen')
    # i18n-tasks-use t('modal.publish.title.publish')
    # i18n-tasks-use t('modal.publish.title.reopen')
    action = procedure.close? ? :reopen : :publish
    t(action, scope: [:modal, :publish, key])
  end

  def procedure_auto_archive_date(procedure)
    I18n.l(procedure.auto_archive_on - 1.day, format: :long)
  end

  def procedure_auto_archive_time(procedure)
    "à 23 h 59 (heure de " + Rails.application.config.time_zone + ")"
  end

  def procedure_auto_archive_datetime(procedure)
    procedure_auto_archive_date(procedure) + ' ' + procedure_auto_archive_time(procedure)
  end

  def can_send_groupe_message?(procedure)
    groupe_instructeur_on_procedure_ids = procedure.groupe_instructeurs.active.ids.sort
    groupe_instructeur_on_instructeur_ids = current_instructeur.groupe_instructeurs.active.where(procedure: procedure).ids.sort

    groupe_instructeur_on_procedure_ids == groupe_instructeur_on_instructeur_ids
  end

  def url_or_email_to_lien_dpo(procedure)
    URI::MailTo.build([procedure.lien_dpo, "subject="]).to_s
  rescue URI::InvalidComponentError
    uri = Addressable::URI.parse(procedure.lien_dpo)
    return "//#{uri}" if uri.scheme.nil?
    uri.to_s
  end

  def estimated_fill_duration_minutes(procedure)
    seconds = procedure.active_revision.estimated_fill_duration
    minutes = (seconds / 60.0).round
    [1, minutes].max
  end

  def admin_procedures_back_path(procedure)
    statut = if procedure.discarded?
      'supprimees'
    else
      case procedure.aasm_state
      when 'brouillon'
        'brouillons'
      when 'close', 'depubliee'
        'archivees'
      else
        'publiees'
      end
    end
    admin_procedures_path(statut:)
  end

  def can_recreate_a_dossier_from_a_procedure?(procedure)
    procedure.closing_reason_internal_procedure? &&
    procedure.replaced_by_procedure.present? &&
    !procedure.replaced_by_procedure.discarded? &&
    procedure.replaced_by_procedure.path.present? # TODO: to remove when all path are added, cf: https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/11453
  end
end
