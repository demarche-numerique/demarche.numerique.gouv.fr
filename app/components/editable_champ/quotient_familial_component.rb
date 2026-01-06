# frozen_string_literal: true

class EditableChamp::QuotientFamilialComponent < EditableChamp::EditableChampBaseComponent
  delegate :fetched?, :fc_data_incorrect?, to: :@champ

  def for_preview?
    @champ.dossier.for_procedure_preview?
  end

  def render_external_champ?
    fetched?
  end

  def render_piece_justificative_champ?
    !fetched? || fc_data_incorrect?
  end

  def qf_data
    if for_preview?
      JSON.parse(
        File.read(
          File.join(__dir__, "quotient_familial_component", "preview_quotient_familial_data.json")
        )
      )
    else
      @champ.value_json
    end
  end
end
