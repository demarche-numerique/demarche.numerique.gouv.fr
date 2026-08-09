# frozen_string_literal: true

class TypesDeChamp::TypeDeChampBase
  delegate :description, :libelle, :mandatory, :mandatory?, :stable_id, :fillable?, :public?, :type_champ, :options_for_select, :drop_down_options, :drop_down_other?, :drop_down_advanced?, :referentiel, :rib?, :justificatif_domicile?, :avis_impot?, :titre_identite?, :ocr_compatible?, to: :@type_de_champ

  FILL_DURATION_SHORT  = 10.seconds
  FILL_DURATION_MEDIUM = 1.minute
  FILL_DURATION_LONG   = 3.minutes
  READ_WORDS_PER_SECOND = 140.0 / 60 # 140 words per minute

  # The revision (or any provider exposing the same tree API, e.g.
  # AggregatedRevision) the type de champ was navigated from; nil on wrappers
  # built outside a tree.
  attr_reader :revision

  def initialize(type_de_champ, revision = nil)
    @type_de_champ = type_de_champ
    @revision = revision
  end

  # The underlying ActiveRecord row. Reach for it to persist changes or build
  # queries; everything read-only should go through the wrapper.
  def record = @type_de_champ

  # Forms, dom_id and routing helpers unwrap to the record.
  def to_model = @type_de_champ

  # A wrapper compares equal to another wrapper (or to a bare record) holding
  # the same row, whichever revision each was navigated from.
  def ==(other)
    case other
    when TypesDeChamp::TypeDeChampBase then @type_de_champ == other.record
    else @type_de_champ == other
    end
  end
  alias eql? ==

  delegate :hash, to: :@type_de_champ

  def tags_for_template
    type_de_champ = @type_de_champ
    conditional = type_de_champ.condition.present?
    paths.map do |path|
      path.merge(
        libelle: TagsSubstitutionConcern::TagsParser.normalize(path[:libelle]),
        id: path[:path] == :value ? "tdc#{stable_id}" : "tdc#{stable_id}/#{path[:path]}",
        conditional:,
        mandatory: mandatory?,
        lambda: -> (dossier) { dossier.champ_value_for_tag(type_de_champ, path[:path]) }
      )
    end
  end

  def libelles_for_export
    paths.map { [_1[:libelle], _1[:path]] }
  end

  # Default estimated duration to fill the champ in a form, in seconds.
  # May be overridden by subclasses.
  def estimated_fill_duration(revision)
    if fillable?
      FILL_DURATION_SHORT
    else
      0.seconds
    end
  end

  def estimated_read_duration
    return 0.seconds if description.blank?

    sanitizer = Rails::Html::Sanitizer.full_sanitizer.new
    content = sanitizer.sanitize(description)

    words = content.split(/\s+/).size

    (words / READ_WORDS_PER_SECOND).round.seconds
  end

  def filter_to_human(filter_value)
    filter_value
  end

  # Public entry points: a blank champ (or one whose stored value belongs to
  # an incompatible former type) falls back to the type's default; the
  # filled_champ_value* / champ_value_blank? hooks below hold the per-type
  # behavior and are what subclasses override.
  def champ_value(champ)
    champ_blank?(champ) ? champ_default_value : filled_champ_value(champ)
  end

  def champ_value_for_api(champ, version: 2)
    champ_blank?(champ) ? champ_default_api_value(version) : filled_champ_value_for_api(champ, version:)
  end

  def champ_value_for_export(champ, path = :value)
    champ_blank?(champ) ? champ_default_export_value(path) : filled_champ_value_for_export(champ, path)
  end

  def champ_value_for_tag(champ, path = :value)
    champ_blank?(champ) ? '' : filled_champ_value_for_tag(champ, path)
  end

  def champ_blank?(champ)
    return true if champ.nil?
    return true if !champ.is_type?(type_champ) && !castable_on_change?(champ.last_write_type_champ, type_champ)

    champ_value_blank?(champ)
  end

  def mandatory_blank?(champ)
    return true if champ.nil?
    return true if !champ.is_type?(type_champ) && !castable_on_change?(champ.last_write_type_champ, type_champ)

    mandatory? && champ_blank_or_invalid?(champ)
  end

  def filled_champ_value(champ)
    champ.value.present? ? champ_text_value(champ) : champ_default_value
  end

  def filled_champ_value_for_api(champ, version: 2)
    case version
    when 2
      filled_champ_value(champ)
    else
      champ.value.presence || champ_default_api_value(version)
    end
  end

  def filled_champ_value_for_export(champ, path = :value)
    path == :value ? champ_text_value(champ).presence : champ_default_export_value(path)
  end

  def filled_champ_value_for_tag(champ, path = :value)
    path == :value ? filled_champ_value(champ) : nil
  end

  def champ_default_value
    ''
  end

  def champ_default_export_value(path = :value)
    nil
  end

  def champ_default_api_value(version = 2)
    case version
    when 2
      ''
    else
      nil
    end
  end

  def champ_value_blank?(champ) = champ.value.blank?
  def champ_blank_or_invalid?(champ) = champ_value_blank?(champ)

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    return nil unless fillable?

    Columns::ChampColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: TypeDeChamp.column_type(type_champ),
      displayable:,
      options_for_select:,
      mandatory: mandatory?
    )
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    [canonical_column(procedure_id:, displayable:, prefix:)].compact
  end

  def personnalisation_column(procedure_id:)
    columns(procedure_id:).find(&:displayable)
  end

  def info_columns(procedure:)
    # Extract labels from columns, removing the libelle prefix automatically
    # Example: "Commune - code postal" => "code postal"
    regex_prefix = /^#{Regexp.escape(libelle)}[^\p{L}]+/

    columns(procedure_id: procedure.id).filter_map do |column|
      column.label.sub(regex_prefix, '')
    end
  end

  def column(column_id)
    columns(procedure_id: nil).find { it.h_id[:column_id] == column_id }
  end

  private

  def castable_on_change?(from_type, to_type)
    Columns::ChampColumn::CAST.key?([from_type.to_sym, to_type.to_sym])
  end

  def champ_text_value(champ)
    if champ.is_type?(TypeDeChamp.type_champs.fetch(:multiple_drop_down_list))
      values = TypesDeChamp::MultipleDropDownListTypeDeChamp.parse_selected_options(champ)
      if @type_de_champ.drop_down_list?
        values.first
      else
        values.join(', ')
      end
    else
      champ.value
    end
  end

  def libelle_with_prefix(prefix)
    # SIRET needs to be explicit in listings for better UI readability
    if type_champ == "siret" && !libelle.upcase.include?("SIRET")
      [prefix, libelle, "SIRET"].compact.join(' – ')
    else
      [prefix, libelle].compact.join(' – ')
    end
  end

  def paths
    [
      {
        libelle:,
        path: :value,
        description:,
      },
    ]
  end
end
