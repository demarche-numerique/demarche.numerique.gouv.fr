# frozen_string_literal: true

module Types
  class CorrectionType < Types::BaseObject
    class CorrectionReason < Types::BaseEnum
      # i18n-tasks-use t('dossier_correction.reasons.incorrect'), t('dossier_correction.reasons.incomplete'), t('dossier_correction.reasons.outdated')
      DossierCorrection.reasons.each do |symbol_name, string_name|
        value(string_name,
          I18n.t(symbol_name, scope: [:activerecord, :attributes, :dossier_correction, :reasons]),
          value: symbol_name)
      end
    end

    field :reason, CorrectionReason, null: false
    field :date_resolution, GraphQL::Types::ISO8601DateTime, null: true

    def date_resolution
      object.resolved_at
    end

    def message
      object.commentaire
    end
  end
end
