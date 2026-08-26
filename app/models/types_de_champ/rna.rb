# frozen_string_literal: true

class TypesDeChamp::RNA < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE

  def customizable? = true

  include AddressableColumnConcern

  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end

  def typed_champ_value_for_export(champ, path = :value)
    champ.identifier
  end

  def info_columns(procedure:)
    # Get base labels from columns (with libelle prefix removed automatically by parent)
    column_labels = super(procedure:)

    # Add exportable columns that are not in the main columns
    column_labels.concat Etablissement::EXPORTABLE_ASSOCIATION_COLUMNS.keys.dup.map { I18n.t(_1, scope: [:activerecord, :attributes, :procedure_presentation, :fields, :etablissement]) }

    column_labels
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    i18n_scope = [:activerecord, :attributes, :procedure_presentation, :fields, :etablissement]

    super
      .concat(addressable_columns(procedure_id:, displayable:, prefix:, deprecated_columns: true))
      .concat(
        Etablissement::EXPORTABLE_ASSOCIATION_COLUMNS.map do |(column, attributes)|
          Columns::JSONPathColumn.new(
            procedure_id:,
            stable_id:,
            tdc_type: type_champ,
            label: [prefix, libelle, I18n.t(column, scope: i18n_scope)].compact.join(' – '),
            type: attributes[:type],
            jsonpath: "$.#{column}",
            displayable: true,
            filterable: attributes.fetch(:filterable, false),
            mandatory: mandatory?
          )
        end
      )
      .concat([
        Columns::JSONPathColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – Titre au répertoire national des associations",
          type: :text,
          jsonpath: '$.title',
          displayable:,
          mandatory: mandatory?
        ),
      ])
  end
end
