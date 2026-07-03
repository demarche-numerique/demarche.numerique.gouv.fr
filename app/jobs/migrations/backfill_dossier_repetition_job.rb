# frozen_string_literal: true

class Migrations::BackfillDossierRepetitionJob < ApplicationJob
  def perform(dossier_ids)
    Dossier.where(id: dossier_ids)
      .includes(:champ_data, revision: :types_de_champ)
      .find_each do |dossier|
        dossier
          .revision
          .types_de_champ
          .filter do |type_de_champ|
            type_de_champ.type_champ == 'repetition' && dossier.champ_data.none? { _1.stable_id == type_de_champ.stable_id }
          end
          .each do |type_de_champ|
            dossier.champ_data << type_de_champ.build_champ_data
          end
      end
  end
end
