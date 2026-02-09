# frozen_string_literal: true

module LLM
  class HeaderComponent < ApplicationComponent
    attr_reader :llm_rule_suggestion

    def initialize(llm_rule_suggestion:)
      @llm_rule_suggestion = llm_rule_suggestion
    end

    def show_last_suggestion_status?
      !llm_rule_suggestion.pending?
    end

    def last_suggestion_status_label
      if llm_rule_suggestion.queued?
        t('.queued')
      else
        searched_at = DateFormatHelper.human(llm_rule_suggestion.created_at)
        t('.last_refresh', searched_at:)
      end
    end

    def accordion_id
      @accordion_id ||= "llm-accordion-#{SecureRandom.hex(4)}"
    end

    class AccordionContentComponent < ApplicationComponent
    end
  end
end
