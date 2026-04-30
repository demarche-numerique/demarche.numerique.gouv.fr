# frozen_string_literal: true

class LLM::ImproveStructureItemComponent < LLM::SuggestionItemComponent
  def self.step_title
    "Structure du formulaire"
  end

  def op_kind
    item.op_kind
  end

  def checkbox(label_class: 'fr-label')
    safe_join([
      form_builder.check_box(:verify_status, {}, ACCEPTED_VALUE, SKIPPED_VALUE),
      form_builder.label(:verify_status, class: label_class) do
        capture { yield if block_given? }
      end,
    ])
  end
end
