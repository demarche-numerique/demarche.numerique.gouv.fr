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
        end
      end
    end
  end
end
