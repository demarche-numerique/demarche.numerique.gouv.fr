# frozen_string_literal: true

module DossierSectionsConcern
  extend ActiveSupport::Concern

  def sections_for(type_de_champ)
    @sections = Hash.new do |hash, parent|
      case parent
      when :public
        hash[parent] = revision.public_root_type_de_champs.filter(&:header_section?)
      when :private
        hash[parent] = revision.private_root_type_de_champs.filter(&:header_section?)
      else
        hash[parent] = revision.children_of(parent).filter(&:header_section?)
      end
    end
    @sections[revision.parent_of(type_de_champ) || (type_de_champ.public? ? :public : :private)]
  end

  def auto_numbering_section_headers_for?(type_de_champ)
    return false if type_de_champ.child?(revision)

    sections_for(type_de_champ)&.none? { _1.libelle =~ /^\d/ }
  end

  def index_for_section_header(header)
    type_de_champs = header.private? ? revision.private_root_type_de_champs : revision.public_root_type_de_champs
    counters = []

    type_de_champs
      .filter(&:header_section?)
      .filter { project_champ(it).visible? }
      .each do |tdc|
      level = tdc.level

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
