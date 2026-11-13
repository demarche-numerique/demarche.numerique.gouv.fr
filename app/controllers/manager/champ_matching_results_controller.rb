# frozen_string_literal: true

module Manager
  class ChampMatchingResultsController < Manager::ApplicationController
    def index
      sections = Kaminari.paginate_array(ChampMatchingResult.sections).page(params[:_page]).per(records_per_page)

      render locals: {
        sections: sections,
        page: Administrate::Page::Collection.new(dashboard),
      }
    end

    def show
      result = ChampMatchingResult.find(params[:id])
      values_visible = administrateur_of_both?(result)
      ranked = values_visible ? result.observations.filter(&:answered?).each.with_index(1).to_a : []

      render locals: {
        result:,
        procedures: Procedure.with_discarded.where(id: [result.procedure_id, result.partner_procedure_id]).pluck(:id, :libelle).to_h,
        values_visible:,
        verdict: params[:verdict],
        observations: Kaminari.paginate_array(filter_by_verdict(ranked, params[:verdict])).page(params[:_page]).per(50),
      }
    end

    private

    # Administrate resolves the route from the class only for an ActiveRecord
    # instance, so a row of this read model never got its link.
    def existing_action?(resource, action_name)
      super(resource.is_a?(ChampMatchingResult) ? resource.class : resource, action_name)
    end

    def administrateur_of_both?(result)
      administrateur = Administrateur.by_email(current_super_admin.email)
      return false if administrateur.nil?

      AdministrateursProcedure.where(administrateur:, procedure_id: [result.procedure_id, result.partner_procedure_id]).count == 2
    end

    def filter_by_verdict(ranked, verdict)
      case verdict
      when 'matching' then ranked.filter { |observation, _rank| observation.matching? }
      when 'differing' then ranked.reject { |observation, _rank| observation.matching? }
      else ranked
      end
    end
  end
end
