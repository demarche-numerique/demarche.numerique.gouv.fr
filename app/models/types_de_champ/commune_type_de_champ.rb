# frozen_string_literal: true

class TypesDeChamp::CommuneTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def champ_value_for_export(champ, path = :value)
    case path
    when :value
      champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def champ_value_for_tag(champ, path = :value)
    case path
    when :value
      champ_value(champ)
    when :departement
      champ.departement_code_and_name || ''
    when :code
      champ.code || ''
    end
  end

  def champ_value(champ)
    if champ.not_in_api_geo?
      champ.value.to_s
    elsif champ.code_postal?
      "#{champ.name} (#{champ.code_postal})"
    else
      champ.name
    end
  end

  def columns(procedure:, displayable: true, prefix: nil)
    super.concat(
      [
        Columns::JSONPathColumn.new(
          procedure_id: procedure.id,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} - code postal (5 chiffres)",
          jsonpath: '$.code_postal',
          displayable:,
          type: :text,
          mandatory: mandatory?
        ),
        Columns::JSONPathColumn.new(
          procedure_id: procedure.id,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} - département",
          jsonpath: '$.code_departement',
          displayable:,
          type: :number,
          mandatory: mandatory?
        ),
      ]
    )
  end

  def info_columns(procedure:)
    Dossiers::CommuneComponent.data_labels
  end

  private

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Code INSEE)",
      description: "#{description} (Code INSEE)",
      path: :code,
      maybe_null: public? && !mandatory?,
    })
    paths.push({
      libelle: "#{libelle} (Département)",
      description: "#{description} (Département)",
      path: :departement,
      maybe_null: public? && !mandatory?,
    })
    paths
  end
end
