# frozen_string_literal: true

module ChampConditionalConcern
  extend ActiveSupport::Concern

  def conditional?
    type_de_champ.read_attribute_before_type_cast('condition').present?
  end

  def dependent_conditions?
    dossier.revision.dependent_conditions(type_de_champ).any?
  end

  def visible?
    # Huge gain perf for cascade conditions
    return @visible if instance_variable_defined? :@visible

    return false if parent_hidden?

    @visible = if conditional?
      type_de_champ.condition.compute(champs_for_condition)
    else
      true
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
    # if there is no row_id, it always has been a root champ
    return false if !child?

    # otherwise maybe the champ has been moved outside a repetition
    parent_tdc = dossier.revision.repetition_of(type_de_champ)

    return false if parent_tdc.nil?

    parent = dossier.champs
      .find { it.type_de_champ == parent_tdc }

    !parent.visible?
  end
end
