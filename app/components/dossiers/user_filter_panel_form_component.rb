# frozen_string_literal: true

# The filter form (fields + live counts) rendered lazily inside the filter
# panel's turbo-frame. Split out of UserFilterPanelComponent so the panel
# template stays small and the expensive `filter.counts` calls live in one place.
class Dossiers::UserFilterPanelFormComponent < ApplicationComponent
  def initialize(filter:, filter_params:, procedures_for_select:, has_invites:)
    @filter = filter
    @filter_params = filter_params
    @procedures_for_select = procedures_for_select
    @has_invites = has_invites
  end

  attr_reader :filter, :filter_params, :procedures_for_select, :has_invites

  def show_procedure_filter?
    procedures_for_select.size >= 2
  end

  def state_label(ui_state)
    Users::DossierStateMapping.state_label(ui_state)
  end

  def alert_label(alert_key)
    t("filter_panel.alerts.#{alert_key}", scope: 'views.users.dossiers.index')
  end

  def state_checked?(ui_state)
    Array(filter_params[:state]).include?(ui_state)
  end

  def alert_checked?(alert_key)
    Array(filter_params[:alert]).include?(alert_key)
  end

  def alert_keys
    Users::DossierFilterService::ALERT_SCOPES.keys
  end

  def apply_disabled?
    filter.total_count.zero?
  end

  def labeled_count(count)
    tag.span("(#{count.to_i})", class: helpers.class_names('user-filter-panel__count', 'user-filter-panel__count--zero': count.to_i.zero?))
  end
end
