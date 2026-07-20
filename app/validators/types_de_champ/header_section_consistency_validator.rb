# frozen_string_literal: true

class TypesDeChamp::HeaderSectionConsistencyValidator < ActiveModel::EachValidator
  # header levels are checked per scope: root types de champ together, each
  # repetition's children together
  def validate_each(procedure, attribute, types_de_champ)
    types_de_champ.to_a
      .group_by { it.repetition(procedure.draft_revision) }
      .each_value { errors_for_header_sections_order(procedure, attribute, it) }
  end

  private

  def errors_for_header_sections_order(procedure, attribute, types_de_champ)
    types_de_champ
      .map.with_index
      .filter_map { |tdc, i| tdc.header_section? ? [tdc, i] : nil }
      .map { |tdc, i| [tdc, tdc.check_coherent_header_level(types_de_champ.take(i))] }
      .filter { |_tdc, errors| errors.present? } # rubocop:disable Rails/CompactBlank
      .each do |tdc, message|
        procedure.errors.add(
          attribute,
          procedure.errors.generate_message(attribute, :inconsistent_header_section, { value: tdc.libelle, custom_message: message }),
          type_de_champ: tdc
        )
      end
  end
end
