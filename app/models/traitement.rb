# frozen_string_literal: true

class Traitement < ApplicationRecord
  belongs_to :dossier, optional: false
  belongs_to :revision, optional: true, class_name: 'ProcedureRevision'
  scope :en_construction, -> { where(state: Dossier.states.fetch(:en_construction)) }
  scope :en_instruction, -> { where(state: Dossier.states.fetch(:en_instruction)) }
  scope :termine, -> { where(state: Dossier::TERMINE) }

  scope :for_traitement_time_stats, -> (procedure) do
    includes(:dossier)
      .termine
      .where(dossier: procedure.dossiers.visible_by_administration)
      .where.not('dossiers.depose_at' => nil)
      .where.not(processed_at: nil)
      .order(:processed_at)
  end

  def browser=(browser)
    if browser == 'api'
      self.browser_name = browser
      self.browser_version = 2
      self.browser_supported = true
    elsif browser.present?
      self.browser_name = browser.name
      self.browser_version = browser.version
      self.browser_supported = BrowserSupport.supported?(browser)
    end
  end

  def termine? = state.in?(Dossier::TERMINE)
  def has_changes? = revision_id.present? && event.in?([:depose_correction_usager, :depose_correction_instructeur])

  EVENT = [
    :depose,
    :depose_correction_usager,
    :depose_correction_instructeur,
    :passe_en_instruction,
    :accepte,
    :refuse,
    :classe_sans_suite,
    :repasse_en_construction,
    :repasse_en_instruction,
    :passe_en_instruction_automatiquement,
    :accepte_automatiquement,
    :refuse_automatiquement,
  ].index_with { _1.to_s.humanize }

  def event
    if state == Dossier.states.fetch(:en_construction)
      if previous_state.nil?
        :depose
      elsif previous_state == Dossier.states.fetch(:en_construction)
        if instructeur?
          :depose_correction_instructeur
        else
          :depose_correction_usager
        end
      else
        :repasse_en_construction
      end
    elsif state == Dossier.states.fetch(:en_instruction)
      if previous_state != Dossier.states.fetch(:en_construction) && instructeur?
        :repasse_en_instruction
      elsif instructeur?
        :passe_en_instruction
      else
        :passe_en_instruction_automatiquement
      end
    elsif instructeur?
      if state == Dossier.states.fetch(:sans_suite)
        :classe_sans_suite
      else
        state.to_sym
      end
    elsif state == Dossier.states.fetch(:accepte)
      :accepte_automatiquement
    else
      :refuse_automatiquement
    end
  end

  def changed_columns
    if has_changes?
      ChangedColumn.columns(revision, changed_champs, reference_champs)
    else
      []
    end
  end

  def instructeur
    return if instructeur_email.blank?

    Instructeur.eager_load(:user).by_email(instructeur_email)
  end

  private

  # The champs replaced by this correction: they were moved to the checkpoint
  # history stream by the merge. Rows removed by the correction only exist here.
  def reference_champs
    return {} if checkpoint.blank?

    dossier.champ_data.filter { _1.stream == checkpoint }.index_by(&:public_id)
  end

  # The champs merged by this correction. A later correction on the same champ
  # moves them to a newer history stream but keeps their checkpoint.
  def changed_champs
    return {} if checkpoint.blank?

    dossier.champ_data.filter { _1.checkpoint == checkpoint }.index_by(&:public_id)
  end

  def previous_state
    i = dossier.traitements.index(self)
    return if i.zero?
    dossier.traitements[i - 1].state
  end

  def instructeur?
    instructeur_email.present?
  end
end
