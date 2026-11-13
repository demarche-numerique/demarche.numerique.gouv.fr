# frozen_string_literal: true

module DossierLinkHelper
  def dossier_link_summary(dossier, user)
    path = dossier_linked_path(user, dossier)
    numero = "N° #{dossier.id}"
    # No `fr-link` class: it forces font-size 1rem and adds an external-link icon,
    # which looks oversized inside the 0.75rem `.fr-message`. A plain link inherits
    # the surrounding text size, consistent with the rest of the summary.
    numero = link_to(numero, path, target: '_blank', rel: 'noopener') if path.present?

    t('shared.champs.dossier_link.summary_html',
      numero:,
      date: l(dossier.depose_at.to_date),
      libelle: tag.strong(dossier.procedure.libelle),
      organisme: tag.strong(dossier.procedure.organisation_name))
  end

  def dossier_link_card?(dossier)
    controller.try(:nav_bar_profile) == :instructeur &&
      controller.action_name != "print" &&
      !dossier.brouillon? &&
      dossier_linked_path(current_instructeur, dossier).present?
  end

  def dossier_link_card_rows(dossier)
    scope = 'activerecord.attributes.procedure_presentation.fields.dossier_link'
    numero = t('shared.champs.dossier_link.application_link', id: dossier.id)
    link = link_to(numero, dossier_linked_path(current_instructeur, dossier), title: new_tab_suffix(numero), target: '_blank', rel: 'noopener')

    [
      [t(:application_number, scope:), link, { copy: false }],
      [t(:submitted_on, scope:), l(dossier.depose_at.to_date, format: :short)],
      [t(:procedure_title, scope:), dossier.procedure.libelle],
      [t(:procedure_agency, scope:), dossier.procedure.organisation_name],
    ]
  end

  def dossier_linked_path(user, dossier)
    if user.is_a?(Instructeur)
      if user.groupe_instructeurs.include?(dossier.groupe_instructeur)
        instructeur_dossier_path(dossier.procedure, dossier)
      end
    elsif user.owns_or_invite?(dossier)
      dossier_path(dossier)
    end
  end
end
