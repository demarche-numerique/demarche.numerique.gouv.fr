# frozen_string_literal: true

module BilansBdfConcern
  extend ActiveSupport::Concern

  ALLOWED_BILANS_BDF_FORMATS = %w[xlsx ods csv].freeze

  private

  def bilans_bdf_response(etablissement, format, fallback_path)
    extension = validated_bilans_bdf_format(format)

    if extension && etablissement&.entreprise_bilans_bdf.present?
      render extension.to_sym => etablissement.entreprise_bilans_bdf_to_sheet(extension)
    else
      redirect_to fallback_path
    end
  end

  def validated_bilans_bdf_format(format)
    format if format.in?(ALLOWED_BILANS_BDF_FORMATS)
  end
end
