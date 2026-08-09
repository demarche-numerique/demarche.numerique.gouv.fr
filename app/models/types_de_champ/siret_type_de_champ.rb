# frozen_string_literal: true

class TypesDeChamp::SiretTypeDeChamp < TypesDeChamp::TypeDeChampBase
  include AddressableColumnConcern

  def estimated_fill_duration
    FILL_DURATION_MEDIUM
  end

  def champ_blank_or_invalid?(champ) = Siret.new(siret: champ.value).invalid?

  def columns(procedure_id:, displayable: true, prefix: nil)
    super
      .concat(etablissement_columns(procedure_id:, displayable:, prefix:))
      .concat(addressable_columns(procedure_id:, displayable:, prefix:, deprecated_columns: true))
  end

  def info_columns(procedure:)
    # Get base labels from columns (with libelle prefix removed automatically by parent)
    column_labels = super(procedure:)

    # Add exportable columns that are not in the main columns
    column_labels.concat Etablissement::EXPORTABLE_ETABLISSEMENT_COLUMNS.keys.dup.map { I18n.t(_1, scope: [:activerecord, :attributes, :procedure_presentation, :fields, :etablissement]) }
    column_labels.concat Etablissement::EXPORTABLE_ASSOCIATION_COLUMNS.keys.dup.map { I18n.t(_1, scope: [:activerecord, :attributes, :procedure_presentation, :fields, :etablissement]) }

    # Hardcode non columns data
    column_labels << "Bilans BDF"
  end

  private

  def etablissement_columns(procedure_id:, displayable:, prefix:)
    i18n_scope = [:activerecord, :attributes, :procedure_presentation, :fields, :etablissement]

    Etablissement::DISPLAYABLE_COLUMNS.map do |(column, attributes)|
      Columns::JSONPathColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: [prefix, libelle, I18n.t(column, scope: i18n_scope)].compact.join(' – '),
        type: attributes[:type],
        jsonpath: "$.#{column}",
        displayable: true,
        filterable: attributes.fetch(:filterable, true),
        mandatory: mandatory?
      )
    end
  end
end
