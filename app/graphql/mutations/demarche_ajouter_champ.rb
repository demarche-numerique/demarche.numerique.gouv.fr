# frozen_string_literal: true

module Mutations
  class DemarcheAjouterChamp < Mutations::DemarcheBrouillonMutation
    description "Ajouter un champ au brouillon d’une démarche. La révision publiée n’est pas modifiée."

    argument :type, Types::ChampDescriptorType::TypeDeChampType, "Le type du champ.", required: true
    argument :label, String, "Le libellé du champ.", required: true
    argument :description, String, "La description du champ.", required: false
    argument :required, Boolean, "Est-ce que le champ est obligatoire ?", required: false, default_value: false
    argument :annotation, Boolean, "Ajouter le champ aux annotations privées plutôt qu’au formulaire usager.", required: false, default_value: false
    argument :parent_id, ID, "Le bloc répétable dans lequel ajouter le champ.", required: false
    argument :apres_id, ID, "Le champ après lequel ajouter le champ. Sans lui, le champ est ajouté en premier.", required: false
    argument :options, GraphQL::Types::JSON, "Les options propres au type du champ, par exemple `{ \"drop_down_options\": [\"Oui\", \"Non\"] }`.", required: false

    private

    def edit(editor, type:, label:, description: nil, required: false, annotation: false, parent_id: nil, apres_id: nil, options: nil)
      editor.add(
        type_champ: type.to_s,
        libelle: label,
        description:,
        mandatory: required,
        private: annotation,
        parent_stable_id: stable_id_from(parent_id),
        after_stable_id: stable_id_from(apres_id),
        options:
      )
    end
  end
end
