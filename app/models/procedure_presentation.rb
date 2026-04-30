# frozen_string_literal: true

class ProcedurePresentation < ApplicationRecord
  ALL_FILTERS = [
    :a_suivre_filters,
    :suivis_filters,
    :traites_filters,
    :tous_filters,
    :supprimes_filters,
    :supprimes_recemment_filters,
    :expirant_filters,
    :archives_filters,
  ]

  self.ignored_columns += ["displayed_fields", "filters", "sort"]

  belongs_to :assign_to, optional: false
  has_many :exports, dependent: :destroy

  delegate :procedure, :instructeur, to: :assign_to

  attribute :displayed_columns, :column, array: true

  attribute :sorted_column, :sorted_column
  def sorted_column = super || procedure.default_sorted_column # Dummy override to set default value

  attribute :a_suivre_filters, :filtered_column, array: true
  attribute :suivis_filters, :filtered_column, array: true
  attribute :traites_filters, :filtered_column, array: true
  attribute :tous_filters, :filtered_column, array: true
  attribute :supprimes_filters, :filtered_column, array: true
  attribute :supprimes_recemment_filters, :filtered_column, array: true
  attribute :expirant_filters, :filtered_column, array: true
  attribute :archives_filters, :filtered_column, array: true

  attr_writer :admin_default_procedure_presentation_active_virtual

  before_create { self.displayed_columns = procedure.default_displayed_columns }
  before_create :set_default_filters

  validates_associated :displayed_columns, :sorted_column, :a_suivre_filters, :suivis_filters,
    :traites_filters, :tous_filters, :supprimes_filters, :expirant_filters, :archives_filters

  def filters_for(statut)
    send(filters_name_for(statut))
  end

  def destroy_filters_for!(statut)
    update!(filters_name_for(statut) => [])
  end

  def update_filter_for_statut!(statut, filter_key, filter)
    filters_attr = filters_name_for(statut)
    current_filters = send(filters_attr) || []
    update!(filters_attr => current_filters.map { |f| f.id == filter_key ? filter : f })
  end

  def replace_filters!(statut, new_filters_columns)
    filters_attr = filters_name_for(statut)
    current_filters = send(filters_attr) || []

    # if the filter is already present keep it, else add it
    replaced_filters = new_filters_columns.map do |new_filter_column|
      current_filters.find { |f| f.column.id == new_filter_column.id } ||
        FilteredColumn.new(column: new_filter_column)
    end

    update!(filters_attr => replaced_filters)
  end

  def replace_all_filters!(new_filters_columns)
    # this method is used to replace all filters for all statuses
    updates = ALL_FILTERS.each_with_object({}) do |filters_attr, hash|
      current_filters = send(filters_attr) || []

      # if the filter is already present keep it, else add it
      replaced_filters = new_filters_columns.map do |new_filter_column|
        current_filters.find { |f| f.column.id == new_filter_column.id } ||
          FilteredColumn.new(column: new_filter_column)
      end

      hash[filters_attr] = replaced_filters
    end

    update!(updates)
  end

  def clear_filters_values_for_statut!(statut)
    filters_attr = filters_name_for(statut)
    current_filters = send(filters_attr) || []
    reset_filters = current_filters.map { |f| FilteredColumn.new(column: f.column) }
    update!(filters_attr => reset_filters)
  end

  def filters_name_for(statut) = statut.tr('-', '_').then { "#{_1}_filters" }

  def set_default_filters
    default_filters_for_all_statuts = [
      FilteredColumn.new(column: procedure.dossier_state_column),
      FilteredColumn.new(column: procedure.dossier_id_column),
      FilteredColumn.new(column: procedure.dossier_notifications_column),
    ]

    ALL_FILTERS.each do |filters_by_status|
      send("#{filters_by_status}=", default_filters_for_all_statuts) if send(filters_by_status).blank?
    end
  end

  def admin_default_procedure_presentation_active_virtual
    return @admin_default_procedure_presentation_active_virtual if !@admin_default_procedure_presentation_active_virtual.nil?

    procedure&.admin_default_procedure_presentation_active
  end

  def effective_displayed_columns
    if procedure.admin_default_procedure_presentation_active && !customized
      ProcedurePresentation
        .find(procedure.admin_default_procedure_presentation_id)
        .displayed_columns
    else
      displayed_columns
    end
  end
end
