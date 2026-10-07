# frozen_string_literal: true

class TypesDeChamp::PrefillRepetitionTypeDeChamp < TypesDeChamp::PrefillTypeDeChamp
  include ActionView::Helpers::UrlHelper
  include ApplicationHelper

  def possible_values
    safe_join([description, subchamps_all_possible_values].compact, tag.br)
  end

  def example_value
    [row_values_format, row_values_format]
  end

  # A JSON body can carry the rows as an array, a query string cannot: with bare
  # brackets Rack folds `champ_x[][sub][]=a&champ_x[][sub][]=b` into a *single*
  # row holding every value, so a repetition of array-valued sub-champs (commune,
  # EPCI, multiple drop-down list) loses its row boundaries. Indexing the rows
  # keeps them apart; they then arrive as a hash keyed by position.
  def example_value_for_query
    example_value.each_with_index.to_h { |row, index| [index.to_s, row] }
  end

  def to_assignable_attributes(champ, value)
    rows = rows_from(value)
    return [] if rows.blank?

    rows.flat_map.with_index do |repetition, index|
      PrefillRepetitionRow.new(champ, repetition, index, @revision).to_assignable_attributes
    end.compact_blank
  end

  private

  # An API body sends an array of rows; a prefill link sends them indexed, which
  # Rack parses into a hash keyed by position. Accept both.
  def rows_from(value)
    case value
    when Array
      value
    when Hash
      return nil unless value.keys.all? { _1.to_s.match?(/\A\d+\z/) }

      value.sort_by { |index, _| index.to_i }.map { |_, row| row }
    end
  end

  def subchamps_all_possible_values
    tag.ul(safe_join(prefillable_subchamps.map do |prefill_type_de_champ|
      tag.li(safe_join(["champ_#{prefill_type_de_champ.to_typed_id_for_query}: ", prefill_type_de_champ.possible_values]))
    end))
  end

  # Keep each sub-champ's example value in its own type: `to_s` turned the array a
  # commune or an EPCI returns into the literal `'["01500", "01004"]'`, which their
  # `to_assignable_attributes` then rejects for not being an Array (#10610).
  def row_values_format
    @row_example_value ||=
      prefillable_subchamps.map do |prefill_type_de_champ|
      ["champ_#{prefill_type_de_champ.to_typed_id_for_query}", prefill_type_de_champ.example_value]
    end.to_h
  end

  def prefillable_subchamps
    @prefillable_subchamps ||=
      TypesDeChamp::PrefillTypeDeChamp.wrap(@revision.children_of(self), @revision).filter(&:prefillable?)
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
        type_de_champ = revision.type_de_champs.find { _1.stable_id == stable_id }
        next unless type_de_champ

        prefill_type_de_champ = TypesDeChamp::PrefillTypeDeChamp.build(type_de_champ, revision)
        # as for the root champs, which PrefillChamps filters the same way
        next unless prefill_type_de_champ.prefillable?

        subchamp = champ.dossier.champ_for_update(type_de_champ, row_id:, updated_by: nil)
        attributes = prefill_type_de_champ.to_assignable_attributes(subchamp, value)
        [subchamp, attributes] if attributes.present?
      end
    end
  end
end
