# frozen_string_literal: true

class Dossiers::UserSearchComponent < ApplicationComponent
  def initialize(search_terms:, active_filter_count:, filter_params:)
    @search_terms = search_terms
    @active_filter_count = active_filter_count
    @filter_params = filter_params
  end

  attr_reader :search_terms, :active_filter_count, :filter_params

  def filter_button_label
    if active_filter_count.positive?
      t('.filter_panel.open_with_count', count: active_filter_count, scope: 'views.users.dossiers.index', default: "Filtrer les dossiers (#{active_filter_count})")
    else
      t('.filter_panel.open', scope: 'views.users.dossiers.index', default: "Filtrer les dossiers")
    end
  end
end
