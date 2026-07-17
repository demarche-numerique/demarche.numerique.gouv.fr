# frozen_string_literal: true

class Champs::RepetitionController < Champs::ChampController
  def add
    row_id = @champ.add_row(updated_by: current_user.email)
    @row = @champ.rows.find { it.id == row_id }
    @first_champ_id = @champ.focusable_input_id
    @champ.update_timestamps
  end

  def remove
    # Calculate row number before deletion for announcement
    row_index = @champ.row_ids.find_index(params[:row_id])
    @deleted_row_number = row_index ? row_index + 1 : nil
    @champ.remove_row(params[:row_id], updated_by: current_user.email)
    @to_remove = "safe-row-selector-#{params[:row_id]}"
    @to_focus = @champ.focusable_input_id || helpers.dom_id(@champ, :create_repetition)
    @champ.update_timestamps
  end

  private

  def params_row_id
    nil
  end

  def policy_class
    Champs::RepetitionChampPolicy
  end
end
