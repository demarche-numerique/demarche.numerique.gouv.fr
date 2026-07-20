# frozen_string_literal: true

module DossierSectionsConcern
  extend ActiveSupport::Concern

  def sections_for(type_de_champ)
    @sections = Hash.new do |hash, parent|
      case parent
      when :public
        hash[parent] = revision.root_types_de_champ_public.filter(&:header_section?)
      when :private
        hash[parent] = revision.root_types_de_champ_private.filter(&:header_section?)
      else
        hash[parent] = parent.flat_children(revision).filter(&:header_section?)
      end
    end
    @sections[type_de_champ.repetition(revision) || (type_de_champ.public? ? :public : :private)]
  end

  def auto_numbering_section_headers_for?(type_de_champ)
    return false if type_de_champ.in_repetition?(revision)

    sections_for(type_de_champ)&.none? { _1.libelle =~ /^\d/ }
  end

  def index_for_section_header(header)
    types_de_champ = header.private? ? revision.root_types_de_champ_private : revision.root_types_de_champ_public
    counters = []

    types_de_champ
      .filter(&:header_section?)
      .filter { project_champ(it).visible? }
      .each do |tdc|
      level = tdc.level(revision)

      # drop counter with a higher level
      # ex: counters = [1,2,2], new header of level 2, drop last
      counters = counters.first(level)

      # increase current counter
      counters[level - 1] = (counters[level - 1] || 0) + 1

      # in case of missing level (nil), fill it with 1
      counters.map! { it || 1 }

      return counters.join('.') if tdc.stable_id == header.stable_id
    end

    # invisible header: no number
    nil
  end
end
