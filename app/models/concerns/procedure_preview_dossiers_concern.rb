# frozen_string_literal: true

module ProcedurePreviewDossiersConcern
  extend ActiveSupport::Concern

  # The latest deposits of each state, split by revision: only the active one knows every tag.
  # The last given state comes first, as it fills the most tags.
  # An instructeur passes their groupes, to see only their dossiers.
  def preview_dossiers(states:, limit: 20, groupe_instructeur_ids: self.groupe_instructeur_ids)
    latest_by_state = states.map do |state|
      Dossier.visible_by_administration
        .where(groupe_instructeur_id: groupe_instructeur_ids, state:)
        .order_by_depose_at
        .includes(:individual, :etablissement)
        .limit(limit)
        .to_a
    end

    preferred_state = states.last
    current, previous = latest_by_state
      .flat_map { it.each_with_index.to_a }
      .min_by(limit, &:last)
      .map(&:first)
      .sort_by { [it.state == preferred_state ? 0 : 1, -it.depose_at.to_f] }
      .partition { it.revision_id == active_revision.id }

    { current:, previous: }.compact_blank
  end

  def preview_dossier(id, groupe_instructeur_ids: self.groupe_instructeur_ids)
    Dossier.visible_by_administration.where(groupe_instructeur_id: groupe_instructeur_ids).find_by(id:) if id.present?
  end
end
