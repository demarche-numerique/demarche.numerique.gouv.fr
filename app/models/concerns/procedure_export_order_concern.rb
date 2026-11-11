# frozen_string_literal: true

# The types de champ of a spreadsheet export, with or without a template, in
# the order of the aggregated tree (Procedure#aggregated_type_de_champs).
#
# The procedures created before it keep the order their exports had
# (legacy_export_order, TypeDeChampTree.legacy_export_order), until a
# maintenance task finds it is the same.
module ProcedureExportOrderConcern
  extend ActiveSupport::Concern

  # to bump when TypeDeChampTree.legacy_export_order changes what it gives
  LEGACY_EXPORT_ORDER_VERSION = 1

  # The columns of the main sheet: what the dossiers may hold out of any
  # repetition, each repetition having a sheet of its own.
  def type_de_champs_for_procedure_export
    in_export_order(main_sheet_type_de_champs)
  end

  def repetition_type_de_champs_for_procedure_export
    in_export_order(repetition_type_de_champs)
  end

  # the columns of a repetition's sheet
  def repetition_children_for_procedure_export(repetition)
    in_export_order(repetition.fillable_children, repetition:)
  end

  # whether any sheet still comes in another order than the form's
  def legacy_export_order_differs?
    sheets = [[main_sheet_type_de_champs, nil], [repetition_type_de_champs, nil], *repetition_type_de_champs.map { [it.fillable_children, it] }]
    sheets.any? { |type_de_champs, repetition| in_legacy_export_order(type_de_champs, repetition:) != type_de_champs }
  end

  private

  def main_sheet_type_de_champs = aggregated_type_de_champs.root_type_de_champs.filter { it.fillable? && !it.repetition? }

  def repetition_type_de_champs = aggregated_type_de_champs.root_type_de_champs.filter(&:repetition?)

  def in_export_order(type_de_champs, repetition: nil)
    legacy_export_order? ? in_legacy_export_order(type_de_champs, repetition:) : type_de_champs
  end

  def in_legacy_export_order(type_de_champs, repetition:)
    index_by_stable_id = legacy_export_index_by_stable_id.fetch(repetition&.stable_id, {})
    type_de_champs.sort_by.with_index { |type_de_champ, index| [index_by_stable_id.fetch(type_de_champ.stable_id, Float::INFINITY), index] }
  end

  # Cached and memoized as the aggregated tree is. A procedure never published
  # exported its draft in the order of the form.
  def legacy_export_index_by_stable_id
    return {} if published_revision_id.nil?

    @legacy_export_index_by_stable_id ||= {}
    @legacy_export_index_by_stable_id[published_revision_id] ||= begin
      cache_key = ["legacy_export_order", LEGACY_EXPORT_ORDER_VERSION, id, published_revision_id]
      order = Rails.cache.fetch(cache_key, expires_in: 1.month) do
        TypeDeChampTree.legacy_export_order(published_revisions_oldest_first.map(&:type_de_champ_tree))
      end

      order.transform_values { it.each_with_index.to_h }
    end
  end
end
