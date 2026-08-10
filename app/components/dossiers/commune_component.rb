# frozen_string_literal: true

class Dossiers::CommuneComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    render Dossiers::ExternalChampComponent.new(data:, source:)
  end

  def self.data_labels
    [
      t('.municipality'),
      t('.insee_code'),
      I18n.t('shared.dossiers.geo.department'),
      I18n.t('shared.dossiers.geo.region_code'),
    ]
  end

  private

  def data
    [
      [t('.municipality'), champ.to_s],
      [t('.insee_code'), champ.code],
      [t('shared.dossiers.geo.department'), champ.departement_code_and_name],
      [t('shared.dossiers.geo.region_code'), champ.code_region],
    ]
  end

  def source
    t('.source')
  end
end
