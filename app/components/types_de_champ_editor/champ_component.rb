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

  def mandatory_configurable?
    type_de_champ.fillable? && !type_de_champ.must_be_mandatory?
  end

  def libelle_configurable?
    !type_de_champ.type_champ.in?([
      TypeDeChamp.type_champs.fetch(:quotient_familial),
    ])
  end

  def description_configurable?
    !type_de_champ.type_champ.in?([
      TypeDeChamp.type_champs.fetch(:quotient_familial),
      TypeDeChamp.type_champs.fetch(:header_section),
      TypeDeChamp.type_champs.fetch(:titre_identite),
    ])
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
      title: direction == :up ? 'Déplacer le champ vers le haut' : 'Déplacer le champ vers le bas',
    }
  end

  def input_autofocus
    @focused ? { controller: 'autofocus' } : nil
  end

  def piece_justificative_template_options
    {
      attached_file: type_de_champ.piece_justificative_template,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def notice_explicative_options
    {
      attached_file: type_de_champ.notice_explicative,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def format_families_for_select
    return [] if !defined?(FORMAT_FAMILIES)

    FORMAT_FAMILIES.keys.map do |key|
      [
        key,
        I18n.t("activerecord.attributes.type_de_champ.format_families.#{key}", default: key.to_s.humanize),
        (defined?(FORMAT_FAMILY_EXAMPLES) && FORMAT_FAMILY_EXAMPLES[key]),
      ]
    end
  end

  def options_for_character_limit
    options = [[t('.character_limit.unlimited'), nil]]

    (400..900).step(100).to_a.concat((1000..10000).step(1000).to_a).each do |limit|
      options << [t('.character_limit.limit', limit: limit.to_fs(:delimited)), limit]
    end

    options
  end

  def turbo_confirm
    if coordinate.prefilled_by_type_de_champ
      "Vous avez configuré un pré remplissage de ce champ à partir des données du référentiel du champ « #{coordinate.prefilled_by_type_de_champ.libelle} ». Voulez-vous vraiment le supprimer ?"
    else
      'Êtes vous sûr de vouloir supprimer ce champ ?'
    end
  end
end
