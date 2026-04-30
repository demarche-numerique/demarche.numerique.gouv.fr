# frozen_string_literal: true

class Champs::RNAController < Champs::ChampController
  before_action :ensure_legitimate_access

  def show
    champs_attributes = params.dig(:dossier, :champs_public_attributes) || params.dig(:dossier, :champs_private_attributes)
    rna = champs_attributes.values.first[:value]

    if @champ.fetch_association!(rna)
      validation_context = @champ.public? ? :champs_public_value : :champs_private_value
      @champ.valid?(validation_context)
    end

    @champ.update_timestamps
  end

  private

  def ensure_legitimate_access
    return if @champ.rna?

    head :not_found
  end
end
