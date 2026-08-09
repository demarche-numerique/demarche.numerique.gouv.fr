# frozen_string_literal: true

describe 'Recovery::Revision::LifeCycle' do
  describe '.load_export_destroy_and_import' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :yes_no, libelle: 'YES!!!' }, {}]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:yes_no_type_de_champ) { procedure.published_revision.types_de_champ.first }
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
        procedure.published_revision.remove_type_de_champ(yes_no_type_de_champ.stable_id)
      end

      it do
        expect { DossierPreloader.load_one(dossier) }.not_to raise_error
        expect(dossier.root_champs_public.size).to eq(1)
        expect(dossier.champ_data.size).to eq(2)
        importer.load
        expect { DossierPreloader.load_one(dossier) }.not_to raise_error
        expect(dossier.root_champs_public.size).to eq(2)
      end
    end

    context "when type de champ libelle updated" do
      before do
        dossier
        yes_no_type_de_champ.record.update!(libelle: 'new libelle')
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
