# frozen_string_literal: true

class Dossiers::EpciComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    render Dossiers::ExternalChampComponent.new(data:, source:)
  end

  def self.data_labels
    [I18n.t('shared.dossiers.geo.department'), I18n.t('shared.dossiers.geo.region_code')]
  end

  private

  def data
    [
      ['EPCI', name],
      [t('shared.dossiers.geo.department'), champ.departement_code_and_name],
      [t('shared.dossiers.geo.region_code'), champ.code_region],
    ]
  end

  def name
    if champ.code?
      "#{champ.code} - #{champ}"
    else
      champ.to_s
    end
  end

  def source = tag.span(t(".source_referentials"))
end
