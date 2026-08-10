# frozen_string_literal: true

class Dossiers::AddressComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    if champ.full_address? && champ.france?
      render Dossiers::ExternalChampComponent.new(data:, source:)
    else
      no_ban_address
    end
  end

  def self.data_labels
    [
      t('.address'),
      t('.insee_code'),
      I18n.t('shared.dossiers.geo.department'),
    ]
  end

  private

  def no_ban_address
    safe_join([
      tag.p(class: 'fr-mb-1w copy-zone', role: 'button') { champ.to_s },
      tag.p(class: 'champ-label') { t('.country') },
      tag.p(class: 'champ-content copy-zone') { champ.country_name },
    ])
  end

  def data
    [
      [t('.address'), champ.to_s],
      [t('.insee_code'), champ.city_code],
      [t('shared.dossiers.geo.department'), champ.departement_code_and_name],
    ]
  end

  def source
    tag.acronym(title: t('.ban_title')) { 'BAN' } if champ.ban?
  end
end
