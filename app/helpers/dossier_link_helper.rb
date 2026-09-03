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
