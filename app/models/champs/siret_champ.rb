# frozen_string_literal: true

class Champs::SiretChamp < ChampData
  include APIEntrepriseChampConcern

  belongs_to :etablissement, optional: true, dependent: :destroy, inverse_of: :champ_data

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

  def external_id=(id)
    super
    self.value = siret
  end

  def after_reset_external_data(opts = {})
    old_etablissement = etablissement
    super(etablissement_id: nil, prefilled: false)
    old_etablissement&.destroy
  end

  def ready_for_external_call?
    Siret.new(siret:).valid?
  end

  def fetch_external_data
    return token_unusable_failure if !procedure.api_entreprise_token_usable?

    case APIEntreprise::Sirene.fetch_etablissement(siret, procedure.id)
    in Success(etablissement)
      procedure.forget_api_entreprise_token_rejection!
      Success(etablissement:)
    in Failure => failure
      api_entreprise_failure(failure)
    end
  end

  def search_terms
    etablissement.present? ? etablissement.search_terms : [value]
  end

  def clear
    super
    ChampData.no_touching { etablissement&.destroy }
  end

  def clone_value_from(champ)
    source = champ.try(:etablissement)
    if source.present?
      self.etablissement = source.dup
      ClonePiecesJustificativesService.clone_attachments(source, etablissement)
    end
    super
  end

  def save_additional_job_exception(exception, code)
    exceptions = fetch_external_data_exceptions || []
    exceptions << ExternalDataException.new(error: exception.inspect, code:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end

  private

  def clone_relationships = [*super, :etablissement]

  def update_external_data!(hash)
    etablissement = hash[:etablissement]
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
