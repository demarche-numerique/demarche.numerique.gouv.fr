# frozen_string_literal: true

class EditableChamp::RepetitionComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_champ_container
    :fieldset
  end

  def legend_params
    @champ.description.present? ? { describedby: dom_id(@champ, :repetition) } : {}
  end

  def notice_params
    @champ.description.present? ? { id: dom_id(@champ, :repetition) } : {}
  end

  def show_toggle_all_button?
    @champ.type_de_champ.flat_children.size > 1
  end

  def aria_controls
    @champ.row_ids.map { |row_id| "#{@champ.html_id}-#{row_id}-accordion-accordion-content" }.join(' ')
  end

  def expand_row?(row_id, rows_count)
    rows_count == 1 || row_has_errors?(row_id)
  end

  def row_has_errors?(row_id)
    dossier = @champ.dossier
    return false if dossier.errors.empty?

    children_types = @champ.type_de_champ.flat_children
    public_ids = children_types.map { |tdc| tdc.public_id(row_id) }.to_set

    public_ids.intersect?(errors_public_ids)
  end

  def errors_public_ids
    @errors_public_ids ||= @champ.dossier.errors.filter_map do |error|
      error.inner_error.base.public_id if error.is_a?(ActiveModel::NestedError) && error.inner_error.base.respond_to?(:public_id)
    end.to_set
  end

  def min_repetitions
    @champ.type_de_champ.min_repetitions.to_i
  end

  def max_repetitions
    @champ.type_de_champ.max_repetitions.to_i
  end

  def max_reached?
    @champ.max_reached?
  end

  def show_limits_description?
    return false if !@champ.type_de_champ.limit_repetitions?
    @champ.type_de_champ.min_repetitions.present? || @champ.type_de_champ.max_repetitions.present?
  end

  def limits_description
    tdc = @champ.type_de_champ
    has_min = tdc.min_repetitions.present?
    has_max = tdc.max_repetitions.present?

    if has_min && has_max
      t(".limits_description_both", min: min_repetitions, max: max_repetitions)
    elsif has_min
      t(".limits_description_min", min: min_repetitions)
    else
      t(".limits_description_max", max: max_repetitions)
    end
  end
end
