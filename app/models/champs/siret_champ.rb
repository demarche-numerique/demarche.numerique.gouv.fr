# frozen_string_literal: true

class Champs::SiretChamp < ChampData
  include Dry::Monads[:result]
  validate :validate_etablissement, if: :should_validate_in_current_context?
  normalizes :external_id, with: -> siret { siret.gsub(/[[:space:]]/, "") }

  def has_async_external_data?
    true
  end

  def focusable_input_id(attribute = :value)
    [input_id, :value].compact.join('-')
  end

  def error_id(attribute = :value)
    [html_id, 'error_id', :value].compact.join('-')
  end

  # TODO: remove after T20251029backfillChampSiretExternalStateTask
  def external_id
    idle? && etablissement_id.present? ? value : super
  end

  def siret = external_id

  def after_reset_external_data(opts = {})
    old_etablissement = etablissement
    super(etablissement_id: nil, prefilled: false, value: nil)
    old_etablissement&.destroy
  end

  def ready_for_external_call?
    Siret.new(siret:).valid?
  end

  def fetch_external_data
    case APIEntreprise::Sirene.fetch_etablissement(siret, procedure.id)
    in Success(etablissement)
      Success(etablissement:, value: siret)
    in Failure(retryable: true, type:, code:, **)
      degraded_failure(type, code)
    in Failure(retryable: false, type:, code:, **)
      Failure(retryable: false, error: StandardError.new("API Entreprise: #{type}"), code:)
    end
  end

  def search_terms
    etablissement.present? ? etablissement.search_terms : [value]
  end

  def save_additional_job_exception(exception, code)
    exceptions = fetch_external_data_exceptions || []
    exceptions << ExternalDataException.new(error: exception.inspect, code:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end

  private

  def degraded_failure(type, code)
    Failure(degraded: true, value: siret, error: StandardError.new("API Entreprise: #{type}"), code:)
  end

  # Only a fetch brings an etablissement: the degraded branch carries the siret alone.
  def update_external_data!(hash)
    etablissement = hash[:etablissement]
    return super if etablissement.nil?

    etablissement.save!
    super(hash.merge(value_json: etablissement.champ_value_json))
    APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedure.id, dossier.user&.id)
  end

  def validate_etablissement
    return if siret.blank?
    return if etablissement.present?
    return if pending? || awaiting_fix?

    validator = ActiveModel::Validations::SiretValidator.new(attributes: { value: true })

    # siret may have been formatted with spaces
    validator.validate_each(self, :external_id, siret.gsub(/[[:space:]]/, ""))

    if errors.empty?
      errors.add(:external_id, :not_found)
    end
  end
end
