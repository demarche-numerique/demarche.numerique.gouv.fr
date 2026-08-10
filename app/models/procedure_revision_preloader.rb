# frozen_string_literal: true

class ProcedureRevisionPreloader
  def initialize(revisions)
    @revisions = revisions
  end

  def all
    revisions = @revisions.to_a
    load_procedure_revision_types_de_champ(revisions)
  end

  def self.load_one(revision)
    ProcedureRevisionPreloader.new([revision]).all.first # rubocop:disable Rails/RedundantActiveRecordAllMethod
  end

  private

  def load_procedure_revision_types_de_champ(revisions)
    revisions_by_id = revisions.index_by(&:id)

    coordinates_by_revision_id = ProcedureRevisionTypeDeChamp
      .where(revision_id: revisions.map(&:id))
      .preload(type_de_champ: { notice_explicative_attachment: :blob, piece_justificative_template_attachment: :blob })
      .order(:position, :id)
      .to_a
      .group_by(&:revision_id)

    coordinates_by_revision_id.each_pair do |revision_id, coordinates|
      revision = revisions_by_id[revision_id]

      coordinates.each do |coordinate|
        coordinate.association(:revision).target = revision
        coordinate.association(:procedure).target = revision.procedure
      end
    end

    assign_revision_type_de_champ(revisions_by_id, coordinates_by_revision_id)
  end

  def assign_revision_type_de_champ(revisions_by_id, coordinates_by_revision_id)
    revisions_by_id.each_pair do |revision_id, revision|
      revision.preload_revision_types_de_champ(coordinates_by_revision_id[revision_id] || [])
    end
  end
end
