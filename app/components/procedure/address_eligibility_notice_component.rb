# frozen_string_literal: true

class Procedure::AddressEligibilityNoticeComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  def render?
    labels.present? && labels.values.flatten.none?(&:nil?)
  end

  private

  def labels
    return @labels if defined?(@labels)

    territories = @procedure.active_revision&.address_eligible_territories
    @labels = territories && {
      departements: territories[:departements].map { APIGeoService.departement_label(it) },
      regions: territories[:regions].map { APIGeoService.region_name(it) },
    }
  end

  # i18n-tasks-use t('.departements_one_html') t('.departements_many_html') t('.regions_one_html') t('.regions_many_html')
  # i18n-tasks-use t('.departements_one_regions_one_html') t('.departements_one_regions_many_html')
  # i18n-tasks-use t('.departements_many_regions_one_html') t('.departements_many_regions_many_html')
  def sentence
    key = labels.filter_map { |kind, names| "#{kind}_#{names.one? ? 'one' : 'many'}" if names.any? }.join('_')

    t(".#{key}_html", **labels.transform_values { list(it) })
  end

  def list(names) = safe_join(names.map { tag.span(it, class: 'no-wrap') }, ', ')
end
