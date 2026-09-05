# frozen_string_literal: true

module Administrateurs::ProceduresHelper
  def render_procedure_sticky_title(procedure)
    content_for(:sticky_header) do
      render partial: "administrateurs/procedures/sticky_title", locals: { procedure: }
    end
  end

  def procedures_filter_path(params = {})
    url_for(params.merge(only_path: true))
  end

  def visible_filter_tags_count(filter)
    count = 0
    count += 1 if filter.email.present?
    count += 1 if filter.service_siret.present?
    count += 1 if filter.service_departement.present?
    count += filter.selected_zones.to_a.size
    count += filter.statuses.to_a.size
    count += 1 if filter.from_publication_date.present?
    if action_name == 'all'
      count += 1 if filter.libelle.present?
      count += filter.kind_usagers.to_a.size
      count += filter.tags.to_a.size
      count += 1 if filter.template?
    end
    count
  end
end
