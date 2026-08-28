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

  def procedure_auto_archive_date(procedure)
    I18n.l(procedure.auto_archive_on - 1.day, format: :long)
  end

  def procedure_auto_archive_time(procedure)
    "à 23 h 59 (heure de " + Rails.application.config.time_zone + ")"
  end

  def procedure_auto_archive_datetime(procedure)
    procedure_auto_archive_date(procedure) + ' ' + procedure_auto_archive_time(procedure)
  end

  def url_or_email_to_lien_dpo(procedure)
    URI::MailTo.build([procedure.lien_dpo, "subject="]).to_s
  rescue URI::InvalidComponentError
    uri = Addressable::URI.parse(procedure.lien_dpo)
    return "//#{uri}" if uri.scheme.nil?
    uri.to_s
  end

  # "3", or "3 à 7" when the conditions make the form shorter or longer.
  def estimated_fill_minutes_text(revision)
    minutes = revision.estimated_fill_duration_minutes

    if minutes.size == 1
      minutes.begin.to_s
    else
      t('helpers.estimated_fill_duration.range', min: minutes.begin, max: minutes.end)
    end
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

  def admin_procedures_back_label(procedure)
    return t('helpers.admin_procedures_back_label.discarded') if procedure.discarded?
    case procedure.aasm_state
    when 'brouillon'
      t('helpers.admin_procedures_back_label.brouillon')
    when 'close', 'depubliee'
      t('helpers.admin_procedures_back_label.close')
    else
      t('helpers.admin_procedures_back_label.publiee')
    end
  end

  def can_recreate_a_dossier_from_a_procedure?(procedure)
    procedure.closing_reason_internal_procedure? &&
    procedure.replaced_by_procedure.present? &&
    !procedure.replaced_by_procedure.discarded? &&
    procedure.replaced_by_procedure.path.present? # TODO: to remove when all path are added, cf: https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/11453
  end
end
