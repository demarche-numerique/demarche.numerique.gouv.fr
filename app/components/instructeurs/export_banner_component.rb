# frozen_string_literal: true

class Instructeurs::ExportBannerComponent < ApplicationComponent
  POLLING_INTERVAL = 5_000

  attr_reader :export

  def initialize(instructeur:)
    @export = instructeur.export_for_banner
  end

  def state
    if export.failed?
      :failed
    elsif export.available?
      :available
    else
      :pending
    end
  end

  def polling? = state == :pending

  private

  def banner_class
    class_names(
      'alert fr-icon--sm fr-text--sm fr-mb-0 fr-py-2w export-banner',
      {
        pending: 'alert-info fr-icon-information-line',
        available: 'alert-success fr-icon-success-line',
        failed: 'alert-danger fr-icon-error-line',
      }.fetch(state)
    )
  end

  def banner_role
    state == :failed ? 'alert' : 'status'
  end

  def banner_data
    if polling?
      {
        controller: 'turbo-poll',
        turbo_poll_url_value: polling_instructeur_export_banner_path,
        turbo_poll_interval_value: POLLING_INTERVAL,
      }
    else
      {}
    end
  end

  def message
    case state
    when :failed
      t('.failed', file_format: export.format)
    when :available
      t('.available_html', file_format: export.format, file_url: export.file.url)
    else
      t('.pending_html', url: exports_instructeur_procedure_path(export.procedure))
    end
  end
end
