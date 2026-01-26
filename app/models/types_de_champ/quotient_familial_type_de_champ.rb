# frozen_string_literal: true

class TypesDeChamp::QuotientFamilialTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def estimated_fill_duration(revision)
    FILL_DURATION_MEDIUM
  end

  def champ_blank?(champ)
    return true if champ.fetched? && champ.fc_data_approved?.nil?
    return false if champ.fc_data_correct?

    if !champ.fetched? || champ.fc_data_incorrect?
      champ.piece_justificative_file.blank?
    end
  end

  def columns(procedure:, displayable: true, prefix: nil)
    Columns::QuotientFamilialColumn::QUOTIENT_FAMILIAL_COLUMNS.map do |label, jsonpath|
      Columns::QuotientFamilialColumn.new(
        procedure_id: procedure.id,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – #{label}",
        jsonpath:,
        displayable:,
        type: :text,
        mandatory: mandatory?
      )
    end
  end
end
