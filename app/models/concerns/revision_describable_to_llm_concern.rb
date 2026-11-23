# frozen_string_literal: true

module RevisionDescribableToLLMConcern
  TYPES_WITH_OPTIONS = %w[formatted integer_number decimal_number date datetime].freeze

  # The form in document order, the content of a repetition right after it. A
  # position counts from 0 among the champs outside any repetition, or within
  # the repetition: header sections hold nothing here.
  def schema_to_llm(reject: [])
    public_root_type_de_champs.each_with_index.flat_map do |tdc, position|
      children = tdc.repetition? ? tdc.flat_children : []

      [
        type_de_champ_to_llm(tdc, position:, reject:),
        *children.each_with_index.map { |child, child_position| type_de_champ_to_llm(child, position: child_position, parent_id: tdc.stable_id, reject:) },
      ]
    end
  end

  private

  def type_de_champ_to_llm(tdc, position:, reject:, parent_id: nil)
    {
      stable_id: tdc.stable_id,
      type: tdc.type_champ,
      libelle: tdc.libelle,
      mandatory: tdc.mandatory?,
      description: tdc.description,
      total_choices: (tdc.drop_down_options.size if tdc.any_drop_down_list?),
      sample_choices: (tdc.drop_down_options.take(5) if tdc.any_drop_down_list?),
      choices_dynamic: (tdc.referentiel.present? ? true : nil),
      position:,
      parent_id:,
      header_section_level: (tdc.block_level if tdc.header_section?),
      display_condition: tdc.condition.present?,
      options: options_for_llm(tdc),
    }.compact.reject { |k, _v| reject.include?(k) }
  end

  def options_for_llm(tdc)
    return nil unless TYPES_WITH_OPTIONS.include?(tdc.type_champ)
    return nil if tdc.options.blank?

    tdc.clean_options.presence
  end
end
