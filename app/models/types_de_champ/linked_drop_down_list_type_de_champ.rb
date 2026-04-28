# frozen_string_literal: true

class TypesDeChamp::LinkedDropDownListTypeDeChamp < TypesDeChamp::TypeDeChampBase
  PRIMARY_PATTERN = /^--(.*)--$/

  validate :check_presence_of_primary_options

  def libelles_for_export
    path = paths.first
    [[path[:libelle], path[:path]]]
  end

  def primary_options
    unpack_options.map(&:first).uniq
  end

  def primary_input_label_id
    "#{input_id}-primary-label"
  end

  def secondary_options
    unpack_options.to_h
  end

  def champ_value(champ)
    [primary_value(champ), secondary_value(champ)].compact_blank.join(' / ')
  end

  def champ_value_for_tag(champ, path = :value)
    case path
    when :primary
      primary_value(champ)
    when :secondary
      secondary_value(champ)
    when :value
      champ_value(champ)
    end
  end

  def champ_value_for_export(champ, path = :value)
    case path
    when :primary
      primary_value(champ)
    when :secondary
      secondary_value(champ)
    when :value
      "#{primary_value(champ) || ''};#{secondary_value(champ) || ''}"
    end
  end

  def champ_value_for_api(champ, version: 2)
    case version
    when 1
      { primary: primary_value(champ), secondary: secondary_value(champ) }
    else
      super
    end
  end

  def champ_blank?(champ)
    primary_value(champ).blank? && secondary_value(champ).blank?
  end

  def champ_blank_or_invalid?(champ)
    primary_value(champ).blank? ||
      (has_secondary_options_for_primary?(champ) && secondary_value(champ).blank?)
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    [
      Columns::LinkedDropDownColumn.new(
        procedure_id:,
        label: libelle_with_prefix(prefix),
        stable_id:,
        tdc_type: type_champ,
        type: :text,
        path: :value,
        displayable:,
        mandatory: mandatory?
      ),
      Columns::LinkedDropDownColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} (Primaire)",
        type: :enum,
        path: :primary,
        displayable: false,
        options_for_select: primary_options.map { [it, it] },
        mandatory: mandatory?
      ),
      Columns::LinkedDropDownColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} (Secondaire)",
        type: :enum,
        path: :secondary,
        displayable: false,
        options_for_select: secondary_options.values.flatten.uniq.sort.map { [it, it] },
        mandatory: mandatory?
      ),
    ]
  end

  private

  def primary_value(champ) = unpack_value(champ.value, 0, primary_options)
  def secondary_value(champ) = unpack_value(champ.value, 1, secondary_options.values.flatten)

  def unpack_value(value, index, options)
    value&.then do
      unpacked_value = JSON.parse(_1)[index]
      unpacked_value if options.include?(unpacked_value)
    rescue
      nil
    end
  end

  def has_secondary_options_for_primary?(champ)
    primary_value(champ).present? && secondary_options[primary_value(champ)]&.any?(&:present?)
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle}/primaire",
      description: "#{description} (Primaire)",
      path: :primary,
      maybe_null: public? && !mandatory?,
    })
    paths.push({
      libelle: "#{libelle}/secondaire",
      description: "#{description} (Secondaire)",
      path: :secondary,
      maybe_null: public? && !mandatory?,
    })
    paths
  end

  def unpack_options
    chunked = drop_down_options.slice_before(PRIMARY_PATTERN)

    chunked.map do |chunk|
      primary, *secondary = chunk
      [PRIMARY_PATTERN.match(primary)&.[](1), secondary.uniq]
    end
  end

  def check_presence_of_primary_options
    if !PRIMARY_PATTERN.match?(drop_down_options.first)
      errors.add(libelle.presence || "La liste", "doit commencer par une entrée de menu primaire de la forme <code style='white-space: pre-wrap;'>--texte--</code>")
    end
  end
end
