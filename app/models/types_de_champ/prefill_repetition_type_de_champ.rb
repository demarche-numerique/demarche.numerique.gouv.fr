# frozen_string_literal: true

class TypesDeChamp::PrefillRepetitionTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  include ActionView::Helpers::UrlHelper
  include ApplicationHelper

  def possible_values
    [
      I18n.t("views.prefill_descriptions.edit.possible_values.#{type_champ}_html"),
      subchamps_all_possible_values,
    ].join("</br>").html_safe
  end

  def example_value
    [row_values_format, row_values_format]
  end

  def to_assignable_attributes(champ, value)
    return [] unless value.is_a?(Array)

    value.flat_map.with_index do |repetition, index|
      PrefillRepetitionRow.new(champ, repetition, index, @revision).to_assignable_attributes
    end.compact_blank
  end

  private

  def subchamps_all_possible_values
    "<ul>" + prefillable_subchamps.map do |prefill_type_de_champ|
      "<li>champ_#{prefill_type_de_champ.to_typed_id_for_query}: #{prefill_type_de_champ.possible_values}</li>"
    end.join + "</ul>"
  end

  def row_values_format
    @row_example_value ||=
      prefillable_subchamps.map do |prefill_type_de_champ|
      ["champ_#{prefill_type_de_champ.to_typed_id_for_query}", prefill_type_de_champ.example_value.to_s]
    end.to_h
  end

  def prefillable_subchamps
    @prefillable_subchamps ||=
      TypesDeChamp::PrefillTypeDeChamp.wrap(@revision.children_of(self).filter(&:prefillable?), @revision)
  end

  class PrefillRepetitionRow
    attr_reader :champ, :repetition, :index, :revision

    def initialize(champ, repetition, index, revision)
      @champ = champ
      @repetition = repetition
      @index = index
      @revision = revision
    end

    def to_assignable_attributes
      return unless repetition.is_a?(Hash)

      row_id = champ.row_ids[index] || champ.add_row(updated_by: nil)

      repetition.filter_map do |key, value|
        next if !key.is_a?(String) || !key.starts_with?("champ_")

        stable_id = ChampData.stable_id_from_typed_id(key)
        type_de_champ = revision.types_de_champ.find { _1.stable_id == stable_id }
        next unless type_de_champ

        subchamp = champ.dossier.champ_for_update(type_de_champ, row_id:, updated_by: nil)
        attributes = TypesDeChamp::PrefillTypeDeChamp.build(subchamp.type_de_champ, revision).to_assignable_attributes(subchamp, value)
        [subchamp, attributes] if attributes.present?
      end
    end
  end
end
