# frozen_string_literal: true

class DubiousProcedure
  extend ActiveModel::Naming
  extend ActiveModel::Translation

  attr_accessor :id, :libelle, :dubious_champs, :aasm_state, :hidden_at_as_template

  FORBIDDEN_KEYWORDS = [
    'NIR', 'RNIPP', 'race', 'religion',
    'carte bancaire', 'carte bleue', 'sécurité sociale',
    'agdref', 'syndicat', 'syndical',
    'parti politique', 'opinion politique', 'bord politique', 'courant politique',
    'médical', 'handicap', 'maladie', 'allergie', 'hospitalisé', 'RQTH', 'vaccin',
  ]

  def persisted?
    false
  end

  def self.all
    type_de_champs = TypeDeChamp
      .dubious
      .joins(:procedure)
      .where(procedures: { closed_at: nil, whitelisted_at: nil })
      .order(:id)
      .pluck(:procedure_id, :id, :libelle)

    # a type de champ removed from a draft lives until the next publication:
    # only the ones a revision lays out are asked of anyone
    laid_out_ids = laid_out_type_de_champ_ids(type_de_champs.map(&:first).uniq)
    dubious_champs = type_de_champs
      .filter { |_, id, _| laid_out_ids.include?(id) }
      .group_by(&:first)
      .transform_values { |versions| versions.map(&:last).uniq.join(' - ') }

    Procedure.with_discarded.where(id: dubious_champs.keys).order(:id).pluck(:id, :libelle, :aasm_state, :hidden_at_as_template).map do |id, libelle, aasm_state, hidden_at_as_template|
      p = DubiousProcedure.new
      p.id = id
      p.dubious_champs = dubious_champs.fetch(id)
      p.libelle = libelle
      p.aasm_state = aasm_state
      p.hidden_at_as_template = hidden_at_as_template
      p
    end
  end

  def self.laid_out_type_de_champ_ids(procedure_ids)
    procedure_ids.each_slice(1_000).each_with_object(Set.new) do |slice, ids|
      ProcedureRevision.where(procedure_id: slice).pluck(:type_de_champ_tree).each { ids.merge(it.type_de_champ_ids) }
    end
  end

  # \\y is a word boundary
  def self.forbidden_regexp
    FORBIDDEN_KEYWORDS.map { |keyword| "\\y#{keyword}\\y" }
      .join('|')
  end
end
