# frozen_string_literal: true

class LLM::SuggestionItemComponent < ApplicationComponent
  ACCEPTED_VALUE = LLMRuleSuggestionItem.verify_statuses.fetch(:accepted)
  SKIPPED_VALUE = LLMRuleSuggestionItem.verify_statuses.fetch(:skipped)

  delegate :llm_rule_suggestion, to: :item
  delegate :procedure_revision, to: :llm_rule_suggestion

  attr_reader :form_builder

  def initialize(form_builder:)
    @form_builder = form_builder
  end

  def item
    form_builder.object
  end

  def payload
    @payload ||= item.payload || {}
  end

  def original_tdc
    @original_tdc ||= tdc_for(item.stable_id)
  end

  def tdc_for(stable_id)
    procedure_revision.find_type_de_champ_by_stable_id(stable_id)
  end
end
