# frozen_string_literal: true

class TypesDeChamp::ByCategoryListComponent < ApplicationComponent
  def initialize(types:)
    @types = types
  end

  private

  def humanized_types_by_category
    @types.sort_by(&:menu_position)
      .group_by(&:category)
      .map { |_, group| group.map { "« #{t(it.sti_name, scope: [:activerecord, :attributes, :type_de_champ, :type_champs])} »" } }
  end
end
