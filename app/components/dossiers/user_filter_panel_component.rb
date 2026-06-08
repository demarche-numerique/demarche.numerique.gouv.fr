# frozen_string_literal: true

class Dossiers::UserFilterPanelComponent < ApplicationComponent
  FRAME_ID = 'filter_panel'

  def initialize(filter:, filter_params:, procedures_for_select:, has_invites:, render_content:)
    @filter = filter
    @filter_params = filter_params
    @procedures_for_select = procedures_for_select
    @has_invites = has_invites
    @render_content = render_content
  end

  attr_reader :filter, :filter_params, :procedures_for_select, :has_invites, :render_content
end
