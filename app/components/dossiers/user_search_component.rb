# frozen_string_literal: true

class Dossiers::UserSearchComponent < ApplicationComponent
  def initialize(search_terms:, active_filter_count:, filter_params:)
    @search_terms = search_terms
    @active_filter_count = active_filter_count
    @filter_params = filter_params
  end

  attr_reader :search_terms, :active_filter_count, :filter_params

  def filter_button_visibility_class
    helpers.class_names('fr-hidden': search_terms.present?)
  end

  def filter_hidden_inputs
    filter_params.to_h.reject { |key, _value| key.to_s == 'search' }.flat_map do |key, value|
      multiple = value.is_a?(Array)
      Array(value).map { |v| [multiple ? "#{key}[]" : key.to_s, v] }
    end
  end

  def form_class
    'user-search-bar__form'
  end
end
