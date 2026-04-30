# frozen_string_literal: true

class LLM::CleanerItemComponent < LLM::SuggestionItemComponent
  def self.step_title
    "Demande unique d’information"
  end

  def render?
    original_tdc.present?
  end

  def checkbox(label_class: 'fr-label')
    safe_join([
      form_builder.check_box(:verify_status, { data: { action: "click->enable-submit-if-checked#click" } }, ACCEPTED_VALUE, SKIPPED_VALUE),
      form_builder.label(:verify_status, class: label_class) do
        capture { yield if block_given? }
      end,
    ])
  end
end
