# frozen_string_literal: true

module Mutations
  class DemarcheSupprimerChamp < Mutations::DemarcheBrouillonMutation
    description "Supprimer un champ du brouillon d’une démarche. Un bloc répétable est supprimé avec ses champs."

    argument :champ_id, ID, "Le champ à supprimer.", required: true

    private

    def edit(editor, champ_id:)
      editor.remove(stable_id_from(champ_id))
    end
  end
end
