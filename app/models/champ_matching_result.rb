# frozen_string_literal: true

class ChampMatchingResult
  include ActiveModel::Model

  Section = Data.define(:procedure_id, :libelle, :partners) do
    def couples_count = partners.sum { it.couples.size }
    def confirmed_count = partners.sum { |partner| partner.couples.count(&:confirmed) }
  end

  Partner = Data.define(:procedure_id, :libelle, :common_users_count, :couples)

  attr_accessor :id,
                :procedure_id, :stable_id, :libelle,
                :partner_procedure_id, :partner_stable_id, :partner_libelle,
                :common_users_count, :matching_users_count, :score, :confirmed

  class << self
    # One section per procedure, so a match appears under each of its two
    # procedures. Grouping keeps the order it reads, so the best score of a
    # couple carries its partner, and the best partner carries its procedure.
    def sections
      matches = TypeDeChampMatch.by_score.to_a
      return [] if matches.empty?

      procedure_ids = matches.flat_map { [it.left_procedure_id, it.right_procedure_id] }
      libelles = libelles_of(matches)
      procedures = Procedure.with_discarded.where(id: procedure_ids).pluck(:id, :libelle).to_h
      pairs = ProcedureUserOverlap.within(procedure_ids).pluck(:left_procedure_id, :right_procedure_id, :common_users_count)
        .to_h { |left_procedure_id, right_procedure_id, count| [[left_procedure_id, right_procedure_id], count] }

      matches
        .flat_map { [oriented(it, :left, libelles), oriented(it, :right, libelles)] }
        .group_by(&:procedure_id)
        .map { |procedure_id, rows| Section.new(procedure_id:, libelle: procedures[procedure_id], partners: partners_of(rows, procedures, pairs)) }
    end

    private

    def partners_of(rows, procedures, pairs)
      rows.group_by(&:partner_procedure_id).map do |partner_procedure_id, couples|
        Partner.new(
          procedure_id: partner_procedure_id,
          libelle: procedures[partner_procedure_id],
          common_users_count: pairs[[couples.first.procedure_id, partner_procedure_id].minmax],
          couples:
        )
      end
    end

    def oriented(match, side, libelles)
      procedure_id, stable_id, partner_procedure_id, partner_stable_id =
        if side == :left
          [match.left_procedure_id, match.left_stable_id, match.right_procedure_id, match.right_stable_id]
        else
          [match.right_procedure_id, match.right_stable_id, match.left_procedure_id, match.left_stable_id]
        end

      new(
        id: match.id,
        procedure_id:,
        stable_id:,
        libelle: libelles[[procedure_id, stable_id]],
        partner_procedure_id:,
        partner_stable_id:,
        partner_libelle: libelles[[partner_procedure_id, partner_stable_id]],
        common_users_count: match.common_users_count,
        matching_users_count: match.matching_users_count,
        score: match.score,
        confirmed: match.confirmed?
      )
    end

    # Ordered by revision, so the last libellé a champ was given wins.
    def libelles_of(matches)
      ProcedureRevisionTypeDeChamp
        .unscope(:eager_load)
        .joins(:revision, :type_de_champ)
        .where(procedure_revisions: { procedure_id: matches.flat_map { [it.left_procedure_id, it.right_procedure_id] } },
               types_de_champ: { stable_id: matches.flat_map { [it.left_stable_id, it.right_stable_id] } })
        .order('procedure_revisions.id')
        .pluck('procedure_revisions.procedure_id', 'types_de_champ.stable_id', 'types_de_champ.libelle')
        .to_h { |procedure_id, stable_id, libelle| [[procedure_id, stable_id], libelle] }
    end
  end
end
