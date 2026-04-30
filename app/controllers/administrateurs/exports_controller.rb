# frozen_string_literal: true

module Administrateurs
  class ExportsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :ensure_not_super_admin!

    def download
      export = Export.find_or_create_fresh_export(export_format, all_groupe_instructeurs, current_administrateur, **export_options)
      @dossiers_count = export.count

      if export.available?
        respond_to do |format|
          format.turbo_stream do
            flash.notice = t('administrateurs.exports.export_available_html', file_format: export.format, file_url: export.file.url)
          end

          format.html do
            redirect_to url_from(export.file.url)
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            if !params[:no_progress_notification]
              flash.notice = t('administrateurs.exports.export_pending')
            end
          end
          format.html do
            redirect_to admin_procedure_archives_url(@procedure), notice: t('administrateurs.exports.export_pending')
          end
        end
      end
    end

    private

    def export_format
      @export_format ||= params[:export_format].presence || export_template&.kind
    end

    def export_template
      return @export_template if defined?(@export_template)
      return @export_template = nil if params[:export_template_id].blank?

      @export_template = @procedure.export_templates.find(params[:export_template_id])
    end

    def export_options
      @export_options ||= {
        time_span_type: params[:time_span_type],
        statut: params[:statut],
        procedure_presentation: nil,
      }.compact
    end

    def all_groupe_instructeurs
      @procedure.groupe_instructeurs
    end
  end
end
