# frozen_string_literal: true

class Dossiers::CommuneComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    if champ.not_in_api_geo?
      render Dossiers::ExternalChampComponent.new(data: fallback_data, source: fallback_source)
    else
      render Dossiers::ExternalChampComponent.new(data:, source:)
    end
  end

  def self.data_labels
    [
      t('.municipality'),
      t('.insee_code'),
      t('.department'),
    ]
  end

  private

  def data
    [
      [t('.municipality'), champ.to_s],
      [t('.insee_code'), champ.code],
      [t('.department'), champ.departement_code_and_name],
    ]
  end

  def source
    t('.source_api_geo')
  end

  def fallback_data
    [[t('.municipality'), champ.value]]
  end

  def fallback_source
    t('.source_free_text')
  end
end
