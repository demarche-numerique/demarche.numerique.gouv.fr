# frozen_string_literal: true

class TypesDeChamp::AnnuaireEducationTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  def self.category = IDENTIFICATION
  def self.icon = 'fr-icon-school-line'

  def prefillable? = false

  include AddressableColumnConcern

  # Every value_json key that is not already covered by
  # AddressableColumnConcern (postal_code, city_name, department_code,
  # region_code) — mirrors what Dossiers::AnnuaireEducationComponent shows
  # in the dossier view.
  ANNUAIRE_EDUCATION_COLUMNS = {
    'nom_etablissement' => { type: :text },
    'identifiant_etablissement' => { type: :text },
    'siren_siret' => { type: :text },
    'street_address' => { type: :text },
    'city_code' => { type: :text },
    'academie' => { type: :text },
    'nature_etablissement' => { type: :text },
    'type_contrat_prive' => { type: :text },
    'nombre_eleves' => { type: :integer },
    'telephone' => { type: :text },
    'email' => { type: :text },
    'site_internet' => { type: :text },
  }.freeze

  def estimated_fill_duration
    FILL_DURATION_MEDIUM
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    super
      .concat(addressable_columns(procedure_id:, displayable:, prefix:))
      .concat(annuaire_education_columns(procedure_id:, displayable:, prefix:))
  end

  private

  def annuaire_education_columns(procedure_id:, displayable:, prefix:)
    i18n_scope = [:activerecord, :attributes, :procedure_presentation, :fields, :annuaire_education]

    ANNUAIRE_EDUCATION_COLUMNS.map do |(column, attributes)|
      Columns::JSONPathColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: [prefix, libelle, I18n.t(column, scope: i18n_scope)].compact.join(' – '),
        type: attributes[:type],
        jsonpath: "$.#{column}",
        displayable:,
        mandatory: mandatory?
      )
    end
  end
end
