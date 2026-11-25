# frozen_string_literal: true

module Recovery
  # Gives the revisions still there the tree they were exported with, and
  # restores the types de champ it lays out.
  class RevisionImporter
    attr_reader :revisions, :type_de_champs

    def initialize(file_path: Recovery::RevisionExporter::FILE_PATH)
      # rubocop:disable Security/MarshalLoad
      dump = Marshal.load(File.read(file_path))
      # rubocop:enable Security/MarshalLoad
      @revisions, @type_de_champs = dump.values_at(:revisions, :type_de_champs)
    end

    def load
      ProcedureRevision.transaction do
        @type_de_champs.each { TypeDeChamp.upsert(it.attributes) }

        @revisions.each do |revision|
          ProcedureRevision.where(id: revision.id).update_all(type_de_champ_tree: revision.type_de_champ_tree.as_json)
          restore_draft_coordinates(revision.id)
        end
      end
    end

    private

    # FIXME: the editor still builds the tree of a draft from its coordinates:
    # they follow the tree restored, until it edits the tree itself (#14009).
    def restore_draft_coordinates(revision_id)
      revision = ProcedureRevision.find_by(id: revision_id)
      return if revision.nil? || !revision.draft?

      ProcedureRevisionTypeDeChamp.where(revision_id:).unscope(:eager_load).delete_all
      revision.create_coordinates_from_type_de_champ_tree
    end
  end
end
