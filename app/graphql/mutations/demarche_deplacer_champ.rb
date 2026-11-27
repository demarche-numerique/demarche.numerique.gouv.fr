# frozen_string_literal: true

module Mutations
  class DemarcheDeplacerChamp < Mutations::DemarcheBrouillonMutation
    description "Déplacer un champ du brouillon d’une démarche, au sein de son bloc."

    argument :champ_id, ID, "Le champ à déplacer.", required: true
    argument :apres_id, ID, "Le champ après lequel le placer. Sans lui, le champ est placé en premier.", required: false

    private

    def edit(editor, champ_id:, apres_id: nil)
      editor.move(stable_id_from(champ_id), after_stable_id: stable_id_from(apres_id))
    end
  end
end
