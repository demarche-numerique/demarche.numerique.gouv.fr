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
    # One query per revision, on purpose: a single batched query would share the
    # type de champ instances across revisions (ActiveRecord caches instantiated
    # rows by id within a query), and per-instance tree state (tdc.coordinate)
    # would leak between the revisions of the batch.
    coordinates_by_revision = revisions.index_with do |revision|
      ProcedureRevisionTypeDeChamp.where(revision_id: revision.id).order(:position, :id).to_a
    end

    ActiveRecord::Associations::Preloader.new(
      records: coordinates_by_revision.values.flatten.map(&:type_de_champ),
      associations: [{ notice_explicative_attachment: :blob, piece_justificative_template_attachment: :blob }]
    ).call

    coordinates_by_revision.each_pair do |revision, coordinates|
      coordinates.each do |coordinate|
        coordinate.association(:revision).target = revision
        coordinate.association(:procedure).target = revision.procedure
      end

      revision.preload_revision_types_de_champ(coordinates)
    end
  end
end
