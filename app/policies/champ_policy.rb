# frozen_string_literal: true

class ChampPolicy < ApplicationPolicy
  def update?
    if dossier.brouillon?
      user_accessible?
    elsif dossier.en_construction?
      user_accessible? || instructeur_accessible?
    end
  end

  def update_annotation?
    return if dossier.brouillon?

    instructeur_accessible?
  end

  private

  def dossier = record.dossier

  # The procedure may require FranceConnect+ to let the dossier's owner or invites at it
  def user_accessible?
    user.owns_or_invite?(dossier) && !dossier.france_connect_plus_missing?(Current.user_session)
  end

  def instructeur_accessible?
    return if !instructeur? || dossier.groupe_instructeur_id.blank?
    instructeur.groupe_instructeurs.exists?(id: dossier.groupe_instructeur_id)
  end
end
