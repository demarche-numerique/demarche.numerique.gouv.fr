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
end
