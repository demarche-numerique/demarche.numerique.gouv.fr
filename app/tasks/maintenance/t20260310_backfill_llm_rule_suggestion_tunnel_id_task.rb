# frozen_string_literal: true

module Maintenance
  class T20260310BackfillLLMRuleSuggestionTunnelIdTask < MaintenanceTasks::Task
    # Documentation: Backfill tunnel_id for existing LLMRuleSuggestion records.
    # Each improve_label starts a new tunnel, and subsequent suggestions in the same
    # procedure share the same tunnel_id until the next improve_label.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      # Process all procedure_revision_ids that have suggestions without tunnel_id
      ProcedureRevision
        .joins(:llm_rule_suggestions)
        .where(llm_rule_suggestions: { tunnel_id: nil })
        .distinct
    end

    def process(procedure_revision)
      # Get all suggestions for this procedure revision without tunnel_id, ordered by created_at
      suggestions = procedure_revision.llm_rule_suggestions
        .where(tunnel_id: nil)
        .order(:created_at)

      current_tunnel_id = nil

      suggestions.each do |suggestion|
        # Each improve_label starts a new tunnel
        if suggestion.rule == 'improve_label'
          current_tunnel_id = generate_unique_tunnel_id(procedure_revision.id)
        end

        # If no tunnel_id is active (orphaned suggestion), create a new one
        current_tunnel_id ||= generate_unique_tunnel_id(procedure_revision.id)

        # Update the suggestion with the tunnel_id
        suggestion.update_column(:tunnel_id, current_tunnel_id)
      end
    end

    def count
      ProcedureRevision
        .joins(:llm_rule_suggestions)
        .where(llm_rule_suggestions: { tunnel_id: nil })
        .distinct
        .count
    end

    private

    def generate_unique_tunnel_id(procedure_revision_id)
      loop do
        tunnel_id = SecureRandom.hex(3)
        unless LLMRuleSuggestion.exists?(procedure_revision_id:, tunnel_id:)
          return tunnel_id
        end
      end
    end
  end
end
