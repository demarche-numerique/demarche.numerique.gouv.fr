# frozen_string_literal: true

class TypesDeChamp::ByCategoryListComponent < ApplicationComponent
  def initialize(types:)
    @types = types
  end

  private

  def humanized_types_by_category
    @types.group_by(&:category)
      .sort_by { |category, _| TypeDeChamp::CATEGORIES.find_index(category) }
      .map { |_, group| group.map { "« #{t(it.type_champ, scope: [:activerecord, :attributes, :type_de_champ, :type_champs])} »" } }
  end
end
