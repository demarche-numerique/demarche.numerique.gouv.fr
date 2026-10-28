# frozen_string_literal: true

module Instructeurs
  class ExportBannersController < InstructeurController
    def polling
      render turbo_stream: turbo_stream.replace('export-banner', Instructeurs::ExportBannerComponent.new(instructeur: current_instructeur))
    end

    def destroy
      current_instructeur.dismiss_export_banner!(params[:export_id].to_i)

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update('export-banner', '') }
        format.html { redirect_back_or_to(instructeur_procedures_path) }
      end
    end
  end
end
