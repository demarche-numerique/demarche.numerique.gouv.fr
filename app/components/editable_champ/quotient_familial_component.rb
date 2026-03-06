# frozen_string_literal: true

class EditableChamp::QuotientFamilialComponent < EditableChamp::EditableChampBaseComponent
  delegate :fetched?, :fc_data_incorrect?, :fc_data_approved?, to: :@champ

  def for_preview?
    @champ.dossier.for_procedure_preview?
  end

  def render_external_champ?
    return render_external_champ_preview? if for_preview?

    fetched?
  end

  def render_piece_justificative_champ?
    return render_piece_justificative_champ_preview? if for_preview?

    !fetched? || fc_data_incorrect?
  end

  def render_data_incorrect_callout?
    return render_data_incorrect_callout_preview? if for_preview?

    fc_data_incorrect?
  end

  def qf_data
    if for_preview?
      JSON.parse(
        File.read(
          File.join(__dir__, "quotient_familial_component", "preview_quotient_familial_data.json")
        )
      )
    else
      @champ.value_json['api_part']
    end
  end

  private

  def render_external_champ_preview?
    @champ.preview_state == 'fetched_preview'
  end

  def render_piece_justificative_champ_preview?
    @champ.preview_state == 'not_fetched_preview' || (@champ.preview_state == 'fetched_preview' && fc_data_approved? == false)
  end

  def render_data_incorrect_callout_preview?
    !fc_data_approved?
  end
end
