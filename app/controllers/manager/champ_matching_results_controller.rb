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
  end
end
