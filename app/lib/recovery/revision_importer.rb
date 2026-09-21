# frozen_string_literal: true

module Recovery
  class RevisionImporter
    attr_reader :revisions

    def initialize(file_path: Recovery::RevisionExporter::FILE_PATH)
      # rubocop:disable Security/MarshalLoad
      @revisions = Marshal.load(File.read(file_path))
      # rubocop:enable Security/MarshalLoad
    end

    def load
      @revisions.each do |revision|
        ProcedureRevisionTypeDeChamp.transaction do
          revision.revision_type_de_champs.each do |coordinate|
            ProcedureRevisionTypeDeChamp.upsert(coordinate.attributes)
            TypeDeChamp.upsert(coordinate.type_de_champ.attributes.except('type_champs'))
          end
          ProcedureRevision.find_by(id: revision.id)&.store_type_de_champ_tree
        end
      end
    end
  end
end
