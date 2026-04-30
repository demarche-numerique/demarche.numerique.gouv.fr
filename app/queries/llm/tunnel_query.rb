# frozen_string_literal: true

module LLM
  class TunnelQuery
    def initialize(procedure_revision:, tunnel_id:)
      @procedure_revision = procedure_revision
      @tunnel_id = tunnel_id
    end

    def self.any_finished?(procedure_revision_id:)
      LLMRuleSuggestion
        .exists?(
          procedure_revision_id: procedure_revision_id,
          rule: LLM::Rule::SEQUENCE.last,
          state: [:accepted, :skipped]
        )
    end

    def self.find_active_tunnel_id_for(procedure_revision)
      finished_tunnel_ids = procedure_revision.llm_rule_suggestions
        .where(rule: LLM::Rule::SEQUENCE.last, state: [:accepted, :skipped])
        .pluck(:tunnel_id)

      # Return most recent active tunnel (deterministic)
      procedure_revision.llm_rule_suggestions
        .where.not(tunnel_id: finished_tunnel_ids)
        .order(created_at: :desc)
        .first
        &.tunnel_id
    end

    def finished?
      first_step_exists? && last_step_finished?
    end

    def first_step_exists?
      base_scope.exists?(rule: LLM::Rule::SEQUENCE.first)
    end

    def last_step_finished?
      base_scope.exists?(
        rule: LLM::Rule::SEQUENCE.last,
        state: [:accepted, :skipped]
      )
    end

    def last_completed_step
      base_scope
        .where(state: [:accepted, :skipped, :completed])
        .order(created_at: :desc)
        .first
    end

    def find_for_rule(rule:)
      base_scope
        .includes(procedure_revision: :llm_rule_suggestions)
        .where(rule:, schema_hash: current_schema_hash)
        .first
    end

    def build_for_rule(rule:)
      @procedure_revision.llm_rule_suggestions.build(
        tunnel_id: @tunnel_id,
        rule:,
        schema_hash: current_schema_hash
      )
    end

    def find_completed(id:, rule:)
      base_scope
        .completed
        .where(rule:, schema_hash: current_schema_hash)
        .includes(:llm_rule_suggestion_items, procedure_revision: :llm_rule_suggestions)
        .find_by(id:)
    end

    def in_progress?(rule:)
      base_scope.exists?(
        rule:,
        schema_hash: current_schema_hash,
        state: [:queued, :running]
      )
    end

    def find_or_create_next_step!(current_rule:)
      next_rule = LLM::Rule.next_rule(current_rule)
      return nil unless next_rule

      @procedure_revision.llm_rule_suggestions.find_or_create_by!(
        tunnel_id: @tunnel_id,
        rule: next_rule
      ) do |suggestion|
        suggestion.schema_hash = current_schema_hash
        suggestion.state = :pending
      end
    end

    private

    def base_scope
      @base_scope ||= LLMRuleSuggestion.where(
        procedure_revision_id: @procedure_revision.id,
        tunnel_id: @tunnel_id
      )
    end

    def current_schema_hash
      # Don't memoize: schema can change during action (e.g., in accept_simplification)
      Digest::SHA256.hexdigest(@procedure_revision.reload.schema_to_llm.to_json)
    end
  end
end
