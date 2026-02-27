# frozen_string_literal: true

module ChampValidateConcern
  extend ActiveSupport::Concern

  included do
    validates_with ExternalDataChampValidator, if: :validate_external_data_response?

    protected

    # Champs public/private must be validated depending on the context
    def valid_champ_value?
      valid?(public? ? :champs_public_value : :champs_private_value)
    end

    private

    def validate_champ_value?
      case validation_context
      when :champs_public_value
        public? && can_validate? && visible?
      when :champs_private_value
        private? && can_validate? && visible?
      when :prefill
        true
      else
        false
      end
    end

    def can_validate?
      in_dossier_stream? && in_dossier_revision? && is_same_type_as_revision? && !row? && !in_discarded_row?
    end

    def in_dossier_stream?
      dossier.stream == stream
    end

    def validate_external_data_response?
      validate_champ_value? && has_async_external_data? && external_data_needed_for_validation?
    end
  end
end
