# frozen_string_literal: true

module Maintenance
  class CleanHeaderSectionOptionsTask < MaintenanceTasks::Task
    # In the rest of PR 10713
    # TypeDeChamp options may contain options which are not consistent with the
    # type_champ (e.g. a `header_section` TypeDeChamp which has a
    # drop_down_options key/value in its options).
    # The aim here is to clean up the options so that only those wich are useful
    # for the type_champ in question.

    def collection
      TypeDeChamp
        .where(type: TypesDeChamp::HeaderSection.name)
        .where.not(options: {})
        .where.not("(SELECT COUNT(*) FROM jsonb_each_text(options)) = 1 AND options ? 'header_section_level'")
    end

    def process(tdc)
      tdc.update(options: tdc.options.slice(:header_section_level))
    end
  end
end
