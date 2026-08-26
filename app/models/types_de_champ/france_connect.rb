# frozen_string_literal: true

class TypesDeChamp::FranceConnect < TypeDeChamp
  def self.category = FRANCE_CONNECT
  def self.public_only? = true
  def self.allowed_in_repetition? = false

  def france_connect? = true
  def api_particulier? = true
  def must_be_mandatory? = true
  def libelle_configurable? = false
  def description_configurable? = false
  def has_label? = false

  REGISTRY = {
    quotient_familial: {
      resource: 'v3/dss/quotient_familial/identite',
      schema: "app/schemas/quotient-familial.json",
      preview_data_file_path: "france_connect_champ_base_component/api_part_preview_data/preview_quotient_familial_data.json",
      rows_builder: FranceConnectChamp::QuotientFamilialRowsBuilder,
      columns: Columns::FranceConnectChampColumn::QUOTIENT_FAMILIAL_COLUMNS,
    },
    etudiant_boursier: {
      resource: 'v4/cnous/etudiant_boursier/identite',
      schema: "app/schemas/etudiant-boursier.json",
      preview_data_file_path: "france_connect_champ_base_component/api_part_preview_data/preview_etudiant_boursier_data.json",
      rows_builder: FranceConnectChamp::EtudiantBoursierRowsBuilder,
      columns: Columns::FranceConnectChampColumn::ETUDIANT_BOURSIER_COLUMNS,
    },
    aah: {
      resource: 'v3/dss/allocation_adulte_handicape/identite',
      schema: "app/schemas/aah.json",
      preview_data_file_path: "france_connect_champ_base_component/api_part_preview_data/preview_aah_data.json",
      rows_builder: FranceConnectChamp::AAHRowsBuilder,
      columns: Columns::FranceConnectChampColumn::AAH_COLUMNS,
    },
    aeeh: {
      resource: 'v3/dss/allocation_enfant_handicape/identite',
      schema: "app/schemas/aeeh.json",
      preview_data_file_path: "france_connect_champ_base_component/api_part_preview_data/preview_aeeh_data.json",
      rows_builder: FranceConnectChamp::AEEHRowsBuilder,
      columns: Columns::FranceConnectChampColumn::AEEH_COLUMNS,
    },
    ars: {
      resource: 'v3/dss/allocation_rentree_scolaire/identite',
      schema: "app/schemas/ars.json",
      preview_data_file_path: "france_connect_champ_base_component/api_part_preview_data/preview_ars_data.json",
      rows_builder: FranceConnectChamp::ARSRowsBuilder,
      columns: Columns::FranceConnectChampColumn::ARS_COLUMNS,
    },
  }.freeze

  def self.config_for(type_champ)
    REGISTRY.fetch(type_champ.to_sym)
  end

  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end

  def typed_champ_blank?(champ)
    return true if champ.fetched? && champ.fc_data_approved?.nil?
    return false if champ.fc_data_correct?

    if !champ.fetched? || champ.fc_data_incorrect?
      champ.piece_justificative_file.blank?
    end
  end

  def typed_champ_value_for_export(champ, path = :value)
    ''
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    TypesDeChamp::FranceConnect.config_for(type_champ)[:columns].map do |label, jsonpath, type|
      Columns::FranceConnectChampColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – #{label}",
        jsonpath:,
        displayable:,
        type:,
        mandatory: mandatory?
      )
    end
  end
end
