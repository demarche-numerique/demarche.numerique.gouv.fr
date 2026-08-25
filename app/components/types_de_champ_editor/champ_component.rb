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
      .map { TypeDeChamp.class_for(_1) }
      .filter(&method(:filter_type_champ))
      .filter(&method(:filter_featured_type_champ))
      .filter(&method(:filter_block_type_champ))
      .filter(&method(:filter_public_or_private_only_type_champ))
      .group_by(&:category)
      .sort_by { |k, _v| TypeDeChamp::CATEGORIES.find_index(k) }
      .to_h do |cat, klasses|
        [
          t(cat, scope: cat_scope),
          klasses.map { [t(_1.type_champ, scope: tdc_scope), _1.name, { disabled: !accepted_types.include?(_1) }] },
        ]
      end
  end

  # the champ cast table still speaks type_champ
  ACCEPTED_TYPES = Columns::ChampColumn::CAST.keys
    .group_by { |(from)| from.to_s }
    .transform_values { |pairs| pairs.map { |(_, to)| to.to_s } }

  def accepted_types
    @accepted_types ||= if published_type_champ.present?
      ([published_type_champ] + ACCEPTED_TYPES.fetch(published_type_champ, [])).uniq.map { TypeDeChamp.class_for(_1) }
    else
      TypeDeChamp.type_champ_classes
    end
  end

  def published_type_champ
    @published_type_champ ||= procedure.published_revision&.type_de_champs&.find { _1.stable_id == type_de_champ.stable_id }&.type_champ
  end

  def disabled_type_de_champ_select?
    coordinate.used_by_routing_rules? || coordinate.used_by_ineligibilite_rules? || accepted_types.size == 1
  end

  def notice_explicative_options
    {
      attached_file: type_de_champ.notice_explicative,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def filter_block_type_champ(klass)
    !coordinate.child? || klass.allowed_in_repetition?
  end

  def filter_public_or_private_only_type_champ(klass)
    coordinate.private? ? !klass.public_only? : !klass.private_only?
  end

  def filter_featured_type_champ(klass)
    klass.feature_flag.nil? || procedure.feature_enabled?(klass.feature_flag)
  end

  def filter_type_champ(klass)
    klass != TypesDeChamp::Number || has_legacy_number?
  end

  def has_legacy_number?
    revision.type_de_champs.any?(&:number?)
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
      "Vous avez configuré un pré remplissage de ce champ à partir des données du référentiel du champ « #{coordinate.prefilled_by_type_de_champ.libelle} ». Voulez-vous vraiment le supprimer ?"
    else
      'Êtes vous sûr de vouloir supprimer ce champ ?'
    end
  end
end
