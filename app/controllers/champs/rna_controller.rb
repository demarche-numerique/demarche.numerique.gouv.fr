# frozen_string_literal: true

class Champs::RNAController < Champs::ChampController
  def show
    champs_attributes = params.dig(:dossier, :champs_public_attributes) || params.dig(:dossier, :champs_private_attributes)
    rna = champs_attributes.values.first[:value]

    @champ.fetch_association!(rna)
    @champ.update_timestamps
  end
end
