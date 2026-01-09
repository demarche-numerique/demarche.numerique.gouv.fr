# frozen_string_literal: true

class PreviewDossierLinkComponent < ApplicationComponent
  def initialize(preview_service:, label: I18n.t('preview_dossier.link_label', default: 'Modifier le dossier de prévisualisation'))
    @preview_service = preview_service
    @label = label
  end

  attr_reader :label

  def edit_path
    @preview_service.edit_path
  end

  private

  attr_reader :preview_service
end
