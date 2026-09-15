# frozen_string_literal: true

class TypesDeChampEditor::ChampComponent < ApplicationComponent
  attr_reader :coordinate, :upper_coordinates

  def initialize(coordinate:, upper_coordinates:, focused: false, errors: '')
    @coordinate = coordinate
    @focused = focused
    @upper_coordinates = upper_coordinates
    @errors = errors
  end

  private

  delegate :type_de_champ, :revision, :procedure, to: :coordinate
  delegate :libelle_configurable?, :description_configurable?, to: :type_de_champ

  def mandatory_configurable?
    type_de_champ.fillable? && !type_de_champ.must_be_mandatory? && !type_de_champ.cannot_be_mandatory?
  end

  def type_de_champ_path
    admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id)
  end

  def html_options
    {
      id: dom_id(coordinate, :type_de_champ_editor),
      class: class_names('type-header-section': type_de_champ.header_section?,
        first: coordinate.first?,
        last: coordinate.last?),
      data: {
        controller: 'type-de-champ-editor',
        type_de_champ_editor_move_up_url_value: move_up_admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
        type_de_champ_editor_move_down_url_value: move_down_admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
      },
    }
  end

  def form_options
    {
      url: admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id),
      html: { multipart: true, id: nil, class: 'form width-100' },
    }
  end

  def move_button_options(direction)
    {
      type: 'button',
      data: { action: 'type-de-champ-editor#onMoveButtonClick', type_de_champ_editor_direction_param: direction },
      title: direction == :up ? t(".move_up_title") : t(".move_down_title"),
    }
  end

  def input_autofocus
    @focused ? { controller: 'autofocus' } : nil
  end

  def notice_explicative_options
    {
      attached_file: type_de_champ.notice_explicative,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def options_for_character_limit
    options = [[t('.character_limit.unlimited'), nil]]

    (400..900).step(100).to_a.concat((1000..10000).step(1000).to_a).each do |limit|
      options << [t('.character_limit.limit', limit: limit.to_fs(:delimited)), limit]
    end

    options
  end

  def prefill_with_france_connect_information_locked_by_sibling?
    return false if type_de_champ.date? && type_de_champ.prefill_with_france_connect_information?

    coordinate.revision.type_de_champs.any? do |tdc|
      tdc.date? && tdc.prefill_with_france_connect_information? && tdc.id != type_de_champ.id
    end
  end

  def turbo_confirm
    if coordinate.prefilled_by_type_de_champ
      t(".confirm_prefilled_removal", libelle: coordinate.prefilled_by_type_de_champ.libelle)
    else
      t(".confirm_removal")
    end
  end
end
