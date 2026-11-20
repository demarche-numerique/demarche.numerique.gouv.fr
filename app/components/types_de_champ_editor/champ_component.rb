# frozen_string_literal: true

class TypesDeChampEditor::ChampComponent < ApplicationComponent
  attr_reader :type_de_champ

  # a type de champ of the draft, laid out: it knows what it sits with
  def initialize(type_de_champ:, focused: false, errors: '')
    @type_de_champ = type_de_champ
    @focused = focused
    @errors = errors
  end

  private

  delegate :libelle_configurable?, :description_configurable?, :revision, to: :type_de_champ
  delegate :procedure, to: :revision

  def siblings
    @siblings ||= type_de_champ.flat_siblings
  end

  def index
    @index ||= siblings.index(type_de_champ)
  end

  def mandatory_configurable?
    type_de_champ.fillable? && !type_de_champ.must_be_mandatory? && !type_de_champ.cannot_be_mandatory?
  end

  def type_de_champ_path
    admin_procedure_type_de_champ_path(procedure, type_de_champ.stable_id)
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

    revision.type_de_champs.any? do |tdc|
      tdc.date? && tdc.prefill_with_france_connect_information? && tdc.id != type_de_champ.id
    end
  end

  def turbo_confirm
    if (prefilled_by = type_de_champ.prefilled_by_type_de_champ)
      t(".confirm_prefilled_removal", libelle: prefilled_by.libelle)
    else
      t(".confirm_removal")
    end
  end
end
