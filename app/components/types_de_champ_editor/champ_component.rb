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

  def types_of_type_de_champ
    cat_scope = "activerecord.attributes.type_de_champ.categorie"
    tdc_scope = "activerecord.attributes.type_de_champ.type_champs"
    TypeDeChamp.type_champs.keys
      .filter(&method(:filter_type_champ))
      .filter(&method(:filter_featured_type_champ))
      .filter(&method(:filter_block_type_champ))
      .filter(&method(:filter_public_or_private_only_type_champ))
      .group_by { TypeDeChamp::TYPE_DE_CHAMP_TO_CATEGORIE.fetch(_1.to_sym) }
      .sort_by { |k, _v| TypeDeChamp::CATEGORIES.find_index(k) }
      .to_h do |cat, tdc|
        [
          t(cat, scope: cat_scope),
          tdc.map { [t(_1, scope: tdc_scope), _1, { disabled: !accepted_type_champs.include?(_1) }] },
        ]
      end
  end

  ACCEPTED_TYPES = Columns::ChampColumn::CAST.keys
    .group_by { |(from)| from.to_s }
    .transform_values { |pairs| pairs.map { |(_, to)| to.to_s } }

  def accepted_type_champs
    @accepted_type_champs ||= if published_type_champ.present?
      ([published_type_champ] + ACCEPTED_TYPES.fetch(published_type_champ, [])).uniq
    else
      TypeDeChamp.type_champs.keys
    end
  end

  def published_type_champ
    @published_type_champ ||= procedure.published_revision&.types_de_champ&.find { _1.stable_id == type_de_champ.stable_id }&.type_champ
  end

  def disabled_type_de_champ_select?
    coordinate.used_by_routing_rules? || coordinate.used_by_ineligibilite_rules? || accepted_type_champs.size == 1
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

  EXCLUDE_FROM_BLOCK = [
    TypeDeChamp.type_champs.fetch(:repetition),
    TypeDeChamp.type_champs.fetch(:quotient_familial),
  ]

  def filter_block_type_champ(type_champ)
    !coordinate.child? || !EXCLUDE_FROM_BLOCK.include?(type_champ)
  end

  def filter_public_or_private_only_type_champ(type_champ)
    if coordinate.private?
      !TypeDeChamp::PUBLIC_ONLY_TYPES.include?(type_champ)
    else
      !TypeDeChamp::PRIVATE_ONLY_TYPES.include?(type_champ)
    end
  end

  def filter_featured_type_champ(type_champ)
    feature_name = TypeDeChamp::FEATURE_FLAGS[type_champ.to_sym]
    feature_name.blank? || procedure.feature_enabled?(feature_name)
  end

  def filter_type_champ(type_champ)
    case type_champ
    when TypeDeChamp.type_champs.fetch(:number)
      has_legacy_number?
    when TypeDeChamp.type_champs.fetch(:cnaf)
      procedure.cnaf_enabled?
    when TypeDeChamp.type_champs.fetch(:dgfip)
      procedure.dgfip_enabled?
    when TypeDeChamp.type_champs.fetch(:pole_emploi)
      procedure.pole_emploi_enabled?
    when TypeDeChamp.type_champs.fetch(:mesri)
      procedure.mesri_enabled?
    else
      true
    end
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

  def has_legacy_number?
    revision.types_de_champ.any?(&:number?)
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
