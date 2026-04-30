# frozen_string_literal: true

module LLM
  class HeaderComponent < ApplicationComponent
    attr_reader :llm_rule_suggestion

    def initialize(llm_rule_suggestion:)
      @llm_rule_suggestion = llm_rule_suggestion
    end

    def show_last_suggestion_status?
      previous_completed_suggestion.present?
    end

    def last_suggestion_status_label
      return unless previous_completed_suggestion

      searched_at = I18n.l(previous_completed_suggestion.created_at, format: :human)
      t('.last_refresh', searched_at:)
    end

    def accordion_id
      @accordion_id ||= "llm-accordion-#{SecureRandom.hex(4)}"
    end

    class AccordionContentComponent < ApplicationComponent
    end

    private

    def previous_completed_suggestion
      @previous_completed_suggestion ||= llm_rule_suggestion
        .procedure_revision
        .llm_rule_suggestions
        .where(tunnel_id: llm_rule_suggestion.tunnel_id)
        .where.not(id: llm_rule_suggestion.id)
        .where(state: [:accepted, :skipped, :completed])
        .order(created_at: :desc)
        .first
    end
  end
end
