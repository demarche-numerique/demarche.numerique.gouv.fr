# frozen_string_literal: true

class BatchOperationProcessOneJob < ApplicationJob
  queue_as :critical
  retry_on StandardError, attempts: 1 # default 5, for now no retryable behavior

  def perform(batch_operation, dossier)
    dossier = batch_operation.dossiers_safe_scope.find(dossier.id)
    begin
      ActiveRecord::Base.transaction do
        batch_operation.process_one(dossier)
        batch_operation.track_processed_dossier(true, dossier, nil)
      end
    rescue => error
      ActiveRecord::Base.transaction do
        error_message = if error.is_a?(AASM::InvalidTransition)
          batch_operation_aasm_error_message(error, dossier)
        else
          error.message
        end
        batch_operation.track_processed_dossier(false, dossier, error_message)
      end
      raise error
    ensure
      batch_operation.finalize_if_complete!
    end
  rescue ActiveRecord::RecordNotFound
    dossier.update_column(:batch_operation_id, nil)
    batch_operation.finalize_if_complete!
  end

  private

  TARGET_STATES = {
    'accepter' => 'accepte',
    'refuser' => 'refuse',
    'classer_sans_suite' => 'sans_suite',
    'passer_en_instruction' => 'en_instruction',
    'repasser_en_construction' => 'en_construction',
  }.freeze

  # Same logic as DossiersController#aasm_error_message, without URL (background job context)
  def batch_operation_aasm_error_message(exception, dossier)
    target_state = TARGET_STATES.fetch(exception.event_name.to_s, exception.originating_state)
    if exception.originating_state == target_state
      I18n.t('instructeurs.dossiers.aasm_error_originating_state', state: dossier_display_state(target_state))
    elsif exception.failures.include?(:can_terminer?) && dossier.any_etablissement_as_degraded_mode?
      I18n.t('instructeurs.dossiers.aasm_error_etablissement_as_degraded_mode', state: dossier_display_state(target_state))
    elsif exception.failures.include?(:can_terminer?) && !dossier.private_champs_valid?
      I18n.t('instructeurs.dossiers.aasm_error_annotations_no_url')
    else
      I18n.t('instructeurs.dossiers.aasm_error_other', originating_state: dossier_display_state(exception.originating_state), target_state: dossier_display_state(target_state))
    end
  end

  # Simplified version of DossierHelper#dossier_display_state
  def dossier_display_state(state, lower: true)
    display_state = Dossier.human_attribute_name("state.#{state}")
    lower ? display_state.downcase : display_state
  end
end
