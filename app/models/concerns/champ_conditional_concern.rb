# frozen_string_literal: true

module ChampConditionalConcern
  extend ActiveSupport::Concern

  def conditional?
    type_de_champ.read_attribute_before_type_cast('condition').present?
  end

  def dependent_conditions?
    dossier.revision.dependent_conditions(type_de_champ).any?
  end

  def section_conditions_hide_champs?
    dossier.procedure.section_conditions_hide_champs?
  end

  # visibility can vary with form data (own condition, repetition membership,
  # or a conditional ancestor section)
  def conditional_visibility?
    conditional? || in_repetition? || (section_conditions_hide_champs? && ancestors.any?(&:conditional?))
  end

  def visible?
    # Huge gain perf for cascade conditions
    return @visible if instance_variable_defined? :@visible

    # a section condition targeting a champ inside the section itself creates
    # a cycle (invalid draft config, reachable until publication); treat the
    # in-progress champ as hidden, so the broken condition computes to nil and
    # the section stays hidden
    return false if @visible_computing

    @visible_computing = true
    begin
      return false if parent_hidden?

      @visible = if conditional?
        type_de_champ.condition.compute(champs_for_condition)
      else
        true
      end
    ensure
      @visible_computing = false
    end
  end

  def submitted_filled?
    return false if dossier.submitted_revision_id.blank?
    return false if dossier.submitted_revision_id == dossier.revision_id

    !type_de_champ.champ_blank?(self)
  end

  def reset_visible # recompute after a dossier update
    remove_instance_variable :@visible if instance_variable_defined? :@visible
    remove_instance_variable :@champs_for_condition if instance_variable_defined? :@champs_for_condition
  end

  private

  def champs_for_condition
    if row_id.nil?
      Array(filled_champs_by_row_id[nil])
    else
      Array(filled_champs_by_row_id[row_id]) + Array(filled_champs_by_row_id[nil])
    end
  end

  def filled_champs_by_row_id
    @filled_champs_by_row_id ||= dossier.filled_champs.group_by(&:row_id)
  end

  def parent_hidden?
    if section_conditions_hide_champs?
      # hidden as soon as the nearest ancestor (section or repetition) is
      # hidden; the parent's own visible? recurses up the ancestor chain
      parent.present? && !parent.visible?
    else
      # legacy: only the repetition ancestor can hide a champ
      # if there is no row_id, it always has been a root champ
      return false if !in_repetition?

      # otherwise maybe the champ has been moved outside a repetition
      parent = repetition
      parent.present? && !parent.visible?
    end
  end
end
