# frozen_string_literal: true

class LLM::ImproveLabelItemComponent < LLM::SuggestionItemComponent
  def self.step_title
    "Libellés et descriptions des champs"
  end

  def render?
    original_tdc.present?
  end

  def libelle_changed?
    payload['libelle'].present? && payload['libelle'] != original_tdc.libelle
  end

  def description_changed?
    payload['description'].present? && payload['description'] != original_tdc.description
  end

  def checkbox
    safe_join([
      form_builder.check_box(:verify_status, { data: { action: "click->enable-submit-if-checked#click" } }, ACCEPTED_VALUE, SKIPPED_VALUE),
      form_builder.label(:verify_status, class: 'fr-label') do
        capture { yield if block_given? }
      end,
    ])
  end
end
