# frozen_string_literal: true

module DossierLinkHelper
  DELETED_DOSSIER_REASON_LABELS = {
    'user_request' => 'supprimé',
    'manager_request' => 'supprimé',
    'user_removed' => 'supprimé',
    'procedure_removed' => 'supprimé',
    'expired' => 'expiré',
    'instructeur_request' => 'supprimé',
    'user_expired' => 'expiré'
  }.freeze

  def dossier_linked_path(user, dossier)
    if user.is_a?(Instructeur)
      if user.groupe_instructeurs.include?(dossier.groupe_instructeur)
        instructeur_dossier_path(dossier.procedure, dossier)
      end
    elsif user.owns_or_invite?(dossier)
      dossier_path(dossier)
    end
  end

  def deleted_dossier_show_summary(deleted_dossier)
    reason_label = DELETED_DOSSIER_REASON_LABELS.fetch(deleted_dossier.reason, 'supprimé')
    depose_part = if deleted_dossier.depose_at.present?
      "Dossier déposé le #{I18n.l(deleted_dossier.depose_at)} sur la démarche "
    else
      "Dossier sur la démarche "
    end

    "#{depose_part}#{deleted_dossier.procedure.libelle} (#{reason_label} le #{I18n.l(deleted_dossier.deleted_at.to_date)})"
  end
end
