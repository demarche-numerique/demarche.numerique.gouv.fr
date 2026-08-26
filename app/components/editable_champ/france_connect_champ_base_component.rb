# frozen_string_literal: true

class EditableChamp::FranceConnectChampBaseComponent < EditableChamp::EditableChampBaseComponent
  delegate :fetched?,
           :fc_data_incorrect?,
           :fc_data_approved?,
           :waiting_for_job?,
           :fetching?,
           :idle?,
           :external_error?,
           to: :@champ

  def for_preview?
    @champ.dossier.for_procedure_preview?
  end

  def render_external_champ?
    return render_external_champ_preview? if for_preview?

    waiting_for_job? || fetching? || fetched?
  end

  def render_piece_justificative_champ?
    return render_piece_justificative_champ_preview? if for_preview?

    idle? || external_error? || fc_data_incorrect?
  end

  def render_data_incorrect_callout?
    return render_data_incorrect_callout_preview? if for_preview?

    fc_data_incorrect?
  end

  def api_part_data
    return api_part_preview_data if for_preview?

    @champ.value_json&.dig('api_part')
  end

  def external_data_component
    FranceConnectChamp::ExternalChampComponent.new(type_champ: @champ.type_champ, data: api_part_data, with_header: true, champ: @champ, for_preview: for_preview?)
  end

  private

  def render_external_champ_preview?
    @champ.preview_state == 'fetched_preview'
  end

  def render_piece_justificative_champ_preview?
    @champ.preview_state == 'not_fetched_preview' ||
      (@champ.preview_state == 'fetched_preview' && fc_data_approved? == false)
  end

  def render_data_incorrect_callout_preview?
    fc_data_approved? == false
  end

  def api_part_preview_data
    JSON.parse(
      File.read(
        File.join(
          __dir__,
          api_part_preview_data_file_path
        )
      )
    )
  end

  def api_part_preview_data_file_path
    TypesDeChamp::FranceConnect.config_for(@champ.type_champ)[:preview_data_file_path]
  end

  def justificatif_label
    t(".justificatif_labels.#{@champ.type_champ}")
  end
end
