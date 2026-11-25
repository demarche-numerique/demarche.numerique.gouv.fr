# frozen_string_literal: true

describe 'Recovery::Revision::LifeCycle' do
  describe '.load_export_destroy_and_import' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no, libelle: 'YES!!!' }, {}]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:yes_no_type_de_champ) { procedure.published_revision.type_de_champs.first }
    let(:file_path) { Rails.root.join('spec', 'fixtures', 'revision_export.dump') }
    let(:exporter) { Recovery::RevisionExporter.new(revision_ids: [procedure.published_revision.id], file_path:) }
    let(:importer) { Recovery::RevisionImporter.new(file_path:) }

    def cleanup_export_file
      file_path.delete if file_path.exist?
    end

    before do
      cleanup_export_file
      procedure.publish!(procedure.administrateurs.first)
      exporter.dump
    end

    after { cleanup_export_file }

    context "when type de champ missing" do
      before do
        dossier
        # its coordinates go with it
        TypeDeChamp.find(yes_no_type_de_champ.id).destroy
        procedure.published_revision.store_type_de_champ_tree # laid by hand: the tree follows
      end

      it do
        expect { DossierPreloader.load_one(dossier) }.not_to raise_error
        expect(dossier.public_root_champs.size).to eq(1)
        expect(dossier.champ_data.size).to eq(2)
        importer.load
        # DossierPreloader reuses a revision already loaded with its types de
        # champ, so the imported one is only visible on a fresh dossier.
        imported_dossier = Dossier.find(dossier.id)
        expect { DossierPreloader.load_one(imported_dossier) }.not_to raise_error
        expect(imported_dossier.public_root_champs.size).to eq(2)
        expect(procedure.published_revision.reload.type_de_champ_tree.public_children.size).to eq(2)
        expect(TypeDeChamp.find(yes_no_type_de_champ.id).libelle).to eq('YES!!!')
      end
    end

    # FIXME: the editor still builds the tree of a draft from its coordinates (#14009)
    context "when a draft lost a type de champ" do
      let(:draft) { procedure.draft_revision }
      let(:exporter) { Recovery::RevisionExporter.new(revision_ids: [draft.id], file_path:) }

      before do
        # its coordinates go with it
        TypeDeChamp.find(yes_no_type_de_champ.id).destroy
        draft.store_type_de_champ_tree # laid by hand: the tree follows
      end

      it "keeps what was restored through the next edit" do
        expect(draft.reload.type_de_champs.map(&:libelle)).not_to include('YES!!!')

        importer.load
        ProcedureRevision.find(draft.id).add_type_de_champ(type_champ: 'text', libelle: 'added')

        expect(ProcedureRevision.find(draft.id).type_de_champs.map(&:libelle)).to include('YES!!!', 'added')
      end
    end

    context "when type de champ libelle updated" do
      before do
        dossier
        yes_no_type_de_champ.update!(libelle: 'new libelle')
      end

      it do
        expect(yes_no_type_de_champ.libelle).to eq('new libelle')
        importer.load
        yes_no_type_de_champ.reload
        expect(yes_no_type_de_champ.libelle).to eq('YES!!!')
      end
    end
  end
end
