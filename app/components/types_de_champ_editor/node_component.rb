# frozen_string_literal: true

# A type de champ in the list of its block: its card, and the button adding a
# type de champ after it.
class TypesDeChampEditor::NodeComponent < ApplicationComponent
  attr_reader :type_de_champ

  # a type de champ of the draft, laid out: it knows what it sits with
  def initialize(type_de_champ:, focused: false, errors: '')
    @type_de_champ = type_de_champ
    @focused = focused
    @errors = errors
  end

  private

  delegate :revision, to: :type_de_champ
  delegate :procedure, to: :revision

  def siblings
    @siblings ||= type_de_champ.flat_siblings
  end

  def index
    @index ||= siblings.index(type_de_champ)
  end

  def html_options
    {
      id: dom_id(type_de_champ, :type_de_champ_editor),
      class: class_names('type-header-section': type_de_champ.header_section?,
        first: index.zero?,
        last: index == siblings.size - 1),
      data: {
        controller: 'type-de-champ-editor',
        type_de_champ_editor_move_up_url_value: move_up_admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
        type_de_champ_editor_move_down_url_value: move_down_admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
      },
    }
  end
end
