# frozen_string_literal: true

class DossierPolicy < ApplicationPolicy
  def read?
    return user_accessible? if record.brouillon?

    user_accessible? || instructeur_accessible?
  end

  private

  # The procedure may require FranceConnect+ to show the dossier to its owner or its invites
  def user_accessible?
    user.owns_or_invite?(record) && !record.france_connect_plus_missing?(Current.user_session)
  end

  def instructeur_accessible?
    return if !instructeur? || record.groupe_instructeur_id.blank?
    instructeur.groupe_instructeurs.exists?(id: record.groupe_instructeur_id)
  end
end
