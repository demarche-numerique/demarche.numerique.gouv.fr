# frozen_string_literal: true

class TypesDeChamp::EpciTypeDeChamp < TypesDeChamp::TextTypeDeChamp
  include AddressableColumnConcern

  def columns(procedure_id:, displayable: true, prefix: nil)
    super.concat(addressable_columns(procedure_id:, displayable:, prefix:, only: [:department_code, :region_code]))
  end

  def filled_champ_value_for_export(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :code
      champ.code
    when :departement
      champ.departement_code_and_name
    end
  end

  def filled_champ_value_for_tag(champ, path = :value)
    case path
    when :value
      filled_champ_value(champ)
    when :code
      champ.code
    when :departement
      champ.departement_code_and_name
    end
  end

  def info_columns(procedure:)
    Dossiers::EpciComponent.data_labels
  end

  private

  def paths
    paths = super
    paths.push({
      libelle: "#{libelle} (Code)",
      description: "#{description} (Code)",
      path: :code,

    })
    paths.push({
      libelle: "#{libelle} (Département)",
      description: "#{description} (Département)",
      path: :departement,

    })
    paths
  end
end
