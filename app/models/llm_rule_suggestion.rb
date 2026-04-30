# frozen_string_literal: true

class LLMRuleSuggestion < ApplicationRecord
  belongs_to :procedure_revision

  has_many :llm_rule_suggestion_items, dependent: :destroy

  enum :state, { pending: 'pending', queued: 'queued', running: 'running', completed: 'completed', failed: 'failed', accepted: 'accepted', skipped: 'skipped' }
  enum :rule, { improve_label: 'improve_label', improve_structure: 'improve_structure', improve_types: 'improve_types', cleaner: 'cleaner' }

  RULE_SEQUENCE = LLM::Rule::SEQUENCE

  scope :last_for_procedure_revision, -> {
    order(created_at: :desc).first
  }

  validates :schema_hash, presence: true
  validates :rule, presence: true, inclusion: { in: LLM::Rule::SEQUENCE }
  validates :tunnel_id, presence: true
  validates :tunnel_id, format: { with: /\A[a-f0-9]{6}\z/ }
  # rubocop:disable Rails/UniqueValidationWithoutIndex : required to run backfill task before adding DB index
  validates :tunnel_id, uniqueness: { scope: [:procedure_revision_id, :rule, :schema_hash] }
  # rubocop:enable Rails/UniqueValidationWithoutIndex : required to run backfill task before adding DB index

  accepts_nested_attributes_for :llm_rule_suggestion_items

  def finished?
    accepted? || skipped?
  end

  def llm_rule_suggestion_items_attributes=(attributes)
    attributes.each do |(_idx, llm_rule_suggestion_items_attribute)|
      llm_rule_suggestion_item = llm_rule_suggestion_items.find { it.id == llm_rule_suggestion_items_attribute[:id].to_i }
      next unless llm_rule_suggestion_item

      if llm_rule_suggestion_items_attribute[:verify_status] == 'accepted'
        llm_rule_suggestion_item.verify_status = 'accepted'
        llm_rule_suggestion_item.applied_at = Time.current
      else
        llm_rule_suggestion_item.verify_status = 'skipped'
        llm_rule_suggestion_item.applied_at = nil
      end
    end
  end

  def changes_to_apply
    llm_rule_suggestion_items.accepted.group_by(&:op_kind).transform_keys(&:to_sym)
  end
end
