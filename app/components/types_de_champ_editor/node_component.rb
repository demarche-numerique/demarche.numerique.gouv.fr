# frozen_string_literal: true

# A type de champ in the list of its block: its card, what a header section or
# a repetition holds, and the button adding a type de champ after it.
class TypesDeChampEditor::NodeComponent < ApplicationComponent
  attr_reader :type_de_champ

  def initialize(type_de_champ:, focused_stable_id: nil, errors: {})
    @type_de_champ = type_de_champ
    @focused_stable_id = focused_stable_id
    @errors = errors
  end

  private

  delegate :revision, to: :type_de_champ

  def holds? = type_de_champ.header_section? || type_de_champ.repetition?
end
