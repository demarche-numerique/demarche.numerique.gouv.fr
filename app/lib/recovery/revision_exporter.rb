# frozen_string_literal: true

module Recovery
  # The revisions, each with its tree and the types de champ it lays out.
  class RevisionExporter
    FILE_PATH = Rails.root.join('lib', 'data', 'revision', 'export.dump')

    attr_reader :revisions, :file_path
    def initialize(revision_ids:, file_path: FILE_PATH)
      @revisions = ProcedureRevision.where(id: revision_ids).to_a
      @file_path = file_path
    end

    def dump
      type_de_champs = TypeDeChamp.where(id: @revisions.flat_map { it.type_de_champ_tree.type_de_champ_ids }.uniq).to_a

      @file_path.binwrite(Marshal.dump({ revisions: @revisions, type_de_champs: }))
    end
  end
end
