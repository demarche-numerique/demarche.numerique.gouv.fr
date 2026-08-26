# frozen_string_literal: true

class TypesDeChamp::RNF < TypesDeChamp::Text
  def self.category = REFERENTIEL_EXTERNE

  def prefillable? = false

  include AddressableColumnConcern

  def typed_champ_value_for_export(champ, path = :value)
    case path
    when :value
      champ.rnf_id
    when :departement
      champ.departement_code_and_name
    when :code_insee
      champ.commune&.fetch(:code)
    when :address
      champ.full_address
    when :nom
      champ.title
    end
  end

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

  def columns(procedure_id:, displayable: true, prefix: nil)
    super
      .concat(addressable_columns(procedure_id:, displayable:, prefix:, deprecated_columns: true))
      .concat([
        Columns::JSONPathColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – Titre au répertoire national des fondations ",
          type: :text,
          jsonpath: '$.title',
          displayable:,
          mandatory: mandatory?
        ),
      ])
  end

  private

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
