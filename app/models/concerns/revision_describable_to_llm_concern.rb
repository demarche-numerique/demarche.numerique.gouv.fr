# frozen_string_literal: true

module RevisionDescribableToLLMConcern
  TYPES_WITH_OPTIONS = %w[formatted integer_number decimal_number date datetime].freeze

  def schema_to_llm(reject: [])
    revision_type_de_champs.includes(:parent, :type_de_champ)
      .filter(&:public?).map do |rtdc|
        {
          stable_id: rtdc.stable_id,
          type: rtdc.type_champ,
          libelle: rtdc.libelle,
          mandatory: rtdc.mandatory?,
          description: rtdc.description,
          total_choices: (rtdc.type_de_champ.drop_down_options.size if rtdc.type_de_champ.any_drop_down_list?),
          sample_choices: (rtdc.type_de_champ.drop_down_options.take(5) if rtdc.type_de_champ.any_drop_down_list?),
          choices_dynamic: (rtdc.type_de_champ.referentiel.present? ? true : nil),
          position: rtdc.position,
          parent_id: rtdc.parent&.stable_id,
          header_section_level: (rtdc.type_de_champ.header_section_level_value if rtdc.type_de_champ.header_section?),
          display_condition: rtdc.type_de_champ.condition.present?,
          options: options_for_llm(rtdc.type_de_champ),
        }.compact.reject { |k, _v| reject.include?(k) }
      end
  end

  private

  def options_for_llm(tdc)
    return nil unless TYPES_WITH_OPTIONS.include?(tdc.type_champ)
    return nil if tdc.options.blank?

    tdc.clean_options.presence
  end
end
