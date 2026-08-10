# frozen_string_literal: true

class Dossiers::DepartementComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    render Dossiers::ExternalChampComponent.new(data:, source:)
  end

  def self.data_labels
    [I18n.t('shared.dossiers.geo.region_code')]
  end

  private

  def data
    [
      [t('shared.dossiers.geo.department'), champ.to_s],
      [t('shared.dossiers.geo.region_code'), champ.code_region],
    ]
  end

  def source = t(".source")
end
