# frozen_string_literal: true

class TypesDeChamp::RNFTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = IDENTIFICATION
  def self.icon = 'fr-icon-community-line'

  def prefillable? = false

  include AddressableColumnConcern

  # value_json keys exposed as columns, with their labels
  DATA_COLUMNS = {
    title: 'Titre au répertoire national des fondations ',
    label: 'Adresse',
    city_code: 'Code INSEE',
  }.freeze

  def typed_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      champ.rnf_id
    when :departement
      champ.departement_code_and_name || ''
    when :code_insee
      champ.commune&.fetch(:code) || ''
    when :address
      champ.full_address || ''
    when :nom
      champ.title || ''
    end
  end

  def typed_champ_blank?(champ) = champ.external_id.blank?

  # the name, the address on one line, the code INSEE and the département
  def legacy_export_columns(procedure_id:)
    super + [
      ["#{libelle} (Nom)", data_column(procedure_id:, displayable: false, prefix: nil, key: :title)],
      ["#{libelle} (Adresse)", data_column(procedure_id:, displayable: false, prefix: nil, key: :label)],
      ["#{libelle} (Code INSEE Ville)", data_column(procedure_id:, displayable: false, prefix: nil, key: :city_code)],
      ["#{libelle} (Département)", addressable_columns(procedure_id:, only: [:department_code]).first],
    ]
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    super
      .concat(addressable_columns(procedure_id:, displayable:, prefix:, deprecated_columns: true))
      .concat(DATA_COLUMNS.keys.map { data_column(procedure_id:, displayable:, prefix:, key: it) })
  end

  private

  def data_column(procedure_id:, displayable:, prefix:, key:)
    Columns::JSONPathColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: "#{libelle_with_prefix(prefix)} – #{DATA_COLUMNS.fetch(key)}",
      type: :text,
      jsonpath: "$.#{key}",
      displayable:,
      mandatory: mandatory?
    )
  end

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Nom)",
      description: "#{description} (Nom)",
      path: :nom,

    })
    paths.push({
      libelle: "#{libelle} (Adresse)",
      description: "#{description} (Adresse)",
      path: :address,

    })
    paths.push({
      libelle: "#{libelle} (Code INSEE Ville)",
      description: "#{description} (Code INSEE Ville)",
      path: :code_insee,

    })
    paths.push({
      libelle: "#{libelle} (Département)",
      description: "#{description} (Département)",
      path: :departement,

    })
    paths
  end
end
