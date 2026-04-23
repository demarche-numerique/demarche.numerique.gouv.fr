# frozen_string_literal: true

class Dossiers::UserActiveFiltersComponent < ApplicationComponent
  def initialize(tags:, current_filter_params:)
    @tags = tags
    @current_filter_params = current_filter_params
  end

  attr_reader :tags, :current_filter_params

  def render?
    tags.any?
  end

  def remove_params_for(tag)
    new_params = current_filter_params.deep_dup.to_h.with_indifferent_access
    case tag[:group]
    when :state, :alert
      new_params[tag[:group]] = Array(new_params[tag[:group]]) - [tag[:value]]
      new_params.delete(tag[:group]) if new_params[tag[:group]].empty?
    else
      new_params.delete(tag[:group])
    end
    new_params
  end

  def reset_params
    { search: current_filter_params[:search] }.compact
  end
end
