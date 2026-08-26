# frozen_string_literal: true

class FranceConnectChamp::ExternalChampComponent < ApplicationComponent
  attr_reader :data

  def initialize(type_champ:, data:, with_header: false, champ: nil, for_preview: false)
    @type_champ = type_champ
    @data = data
    @with_header = with_header
    @champ = champ
    @for_preview = for_preview
  end

  def source
    tag.acronym(t(".external_champ.source.#{@type_champ}"))
  end

  def rows
    return [] if data.nil?

    rows_builder.new.build(data)
  end

  def refresh_disabled?
    return true if @for_preview

    @champ.updated_at > Champs::FranceConnectChamp::REFRESH_DELAY.ago
  end

  private

  def rows_builder
    TypesDeChamp::FranceConnect.config_for(@type_champ)[:rows_builder]
  end
end
