# frozen_string_literal: true

RSpec.describe Export, type: :model do
  describe 'associations' do
    let(:instructeur) { create(:instructeur) }
    let(:export) { create(:export, user_profile_type: 'Instructeur', user_profile_id: instructeur.id) }
    it 'find polymorphic association' do
      expect(export.user_profile).to eq(instructeur)
    end
  end

  describe 'validations' do
    let(:groupe_instructeur) { create(:groupe_instructeur) }

    context 'when everything is ok' do
      let(:export) { build(:export, groupe_instructeurs: [groupe_instructeur]) }

      it { expect(export.save).to be true }
    end

    context 'when groupe instructeurs are missing' do
      let(:export) { build(:export, groupe_instructeurs: []) }

      it { expect(export.save).to be false }
    end

    context 'when format is missing' do
      let(:export) { build(:export, format: nil, groupe_instructeurs: [groupe_instructeur]) }

      it { expect(export.save).to be false }
    end
  end

  describe '.stale' do
    let!(:export) { create(:export) }
    let(:stale_date) { Time.zone.now() - (Export::MAX_DUREE_CONSERVATION_EXPORT + 1.minute) }
    let!(:stale_export_generated) { create(:export, :generated, updated_at: stale_date) }
    let!(:stale_export_failed) { create(:export, :failed, updated_at: stale_date) }
    let!(:stale_export_pending) { create(:export, :pending, updated_at: stale_date) }
    let!(:stale_export_too_large) { create(:export, :too_large, updated_at: stale_date) }

    it { expect(Export.stale(Export::MAX_DUREE_CONSERVATION_EXPORT)).to match_array([stale_export_generated, stale_export_failed, stale_export_too_large]) }
  end

  describe '.stuck' do
    let!(:export) { create(:export) }
    let(:stuck_date) { Time.zone.now() - (Export::MAX_DUREE_GENERATION + 1.minute) }
    let!(:stale_export_generated) { create(:export, :generated, updated_at: stuck_date) }
    let!(:stale_export_failed) { create(:export, :failed, updated_at: stuck_date) }
    let!(:stale_export_pending) { create(:export, :pending, updated_at: stuck_date) }

    it { expect(Export.stuck(Export::MAX_DUREE_GENERATION)).to match_array([stale_export_pending]) }
  end

  describe '.destroy' do
    let!(:groupe_instructeur) { create(:groupe_instructeur) }
    let!(:export) { create(:export, groupe_instructeurs: [groupe_instructeur]) }

    before { export.destroy! }

    it do
      expect(Export.count).to eq(0)
      expect(groupe_instructeur.reload).to be_present
    end
  end

  describe '.find_or_create_fresh_export' do
    let!(:procedure) { create(:procedure) }
    let(:instructeur) { create(:instructeur) }
    let!(:gi_1) { create(:groupe_instructeur, procedure: procedure, instructeurs: [instructeur]) }
    let!(:pp) { gi_1.instructeurs.first.procedure_presentation_and_errors_for_procedure_id(procedure.id).first }
    let(:created_at_column) { FilteredColumn.new(column: procedure.find_column(label: 'Date de création'), filter: '10/12/2021') }

    before { pp.update(tous_filters: [created_at_column]) }

    context 'with procedure_presentation having different filters' do
      it 'works once' do
        expect { Export.find_or_create_fresh_export(:zip, [gi_1], instructeur, time_span_type: Export.time_span_types.fetch(:everything), statut: Export.statuts.fetch(:tous), procedure_presentation: pp) }
          .to change { Export.count }.by(1)
      end

      it 'works once, changes procedure_presentation, recreate a new' do
        expect { Export.find_or_create_fresh_export(:zip, [gi_1], instructeur, time_span_type: Export.time_span_types.fetch(:everything), statut: Export.statuts.fetch(:tous), procedure_presentation: pp) }
          .to change { Export.count }.by(1)

        update_at_column = FilteredColumn.new(column: procedure.find_column(label: 'Date du dernier évènement'), filter: '10/12/2021')
        pp.update(tous_filters: [created_at_column, update_at_column])

        expect { Export.find_or_create_fresh_export(:zip, [gi_1], instructeur, time_span_type: Export.time_span_types.fetch(:everything), statut: Export.statuts.fetch(:tous), procedure_presentation: pp) }
          .to change { Export.count }.by(1)
      end
    end

    context 'with export template' do
      let(:export_template) { create(:export_template, groupe_instructeur: gi_1) }

      it 'creates new export' do
        expect { Export.find_or_create_fresh_export(:zip, [gi_1], instructeur, export_template:, time_span_type: Export.time_span_types.fetch(:everything), statut: Export.statuts.fetch(:tous), procedure_presentation: pp) }
          .to change { Export.count }.by(1)
      end
    end

    context 'with existing matching export' do
      def find_or_create =
        Export.find_or_create_fresh_export(:zip, [gi_1], instructeur, time_span_type: Export.time_span_types.fetch(:everything), statut: Export.statuts.fetch(:tous), procedure_presentation: pp)

      context 'freshly generate export' do
        before { find_or_create.update!(job_status: :generated, updated_at: 1.second.ago) }

        it 'returns current pending export' do
          current_export = find_or_create

          expect(find_or_create).to eq(current_export)
        end
      end

      context 'old generated export' do
        before { find_or_create.update!(job_status: :generated, updated_at: 1.hour.ago) }

        it 'returns a new export' do
          expect { find_or_create }.to change { Export.count }.by(1)
        end
      end

      context 'export refused as too large a moment ago' do
        before { find_or_create.update!(job_status: :too_large, updated_at: 1.second.ago) }

        it 'returns it' do
          expect { find_or_create }.not_to change { Export.count }
        end
      end

      context 'export refused as too large an hour ago' do
        before { find_or_create.update!(job_status: :too_large, updated_at: 1.hour.ago) }

        it 'returns a new export' do
          expect { find_or_create }.to change { Export.count }.by(1)
        end
      end

      context 'pending export' do
        before { find_or_create.update!(updated_at: 1.hour.ago) }

        it 'returns current pending export' do
          current_export = find_or_create
          expect(find_or_create).to eq(current_export)
        end
      end
    end

    context 'when a recent export exists for a different procedure with the same default parameters' do
      let!(:other_procedure) { create(:procedure) }
      let!(:other_groupe_instructeur) { create(:groupe_instructeur, procedure: other_procedure) }
      let!(:other_administrateur) { create(:administrateur) }
      let!(:other_procedure_export) do
        Export.find_or_create_fresh_export(:csv, [other_groupe_instructeur], other_administrateur)
      end

      let!(:requesting_procedure) { create(:procedure) }
      let!(:requesting_groupe_instructeur) { create(:groupe_instructeur, procedure: requesting_procedure) }
      let!(:requesting_administrateur) { create(:administrateur) }

      subject(:requesting_export) do
        Export.find_or_create_fresh_export(:csv, [requesting_groupe_instructeur], requesting_administrateur)
      end

      it 'does not return the export bound to the other procedure' do
        expect(requesting_export).not_to eq(other_procedure_export)
      end

      it 'returns an export scoped to the requesting groupe instructeur' do
        expect(requesting_export.groupe_instructeurs).to contain_exactly(requesting_groupe_instructeur)
      end

      it 'creates a new export for the requesting procedure' do
        expect { requesting_export }.to change { Export.count }.by(1)
      end
    end
  end

  describe '#compute_estimated_files_size' do
    let(:procedure) { create(:procedure, :published, :with_instructeur, public_type_de_champs: [{ type: :piece_justificative, stable_id: 10 }, { type: :piece_justificative, stable_id: 20 }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let(:export) { create(:export, format: :zip, groupe_instructeurs: procedure.groupe_instructeurs, export_template:) }

    before do
      dossier.champs.each { |champ| champ.piece_justificative_file_blobs.each { it.update!(byte_size: champ.stable_id) } }
      create(:commentaire, :with_file, dossier:).piece_jointe.first.blob.update!(byte_size: 1, virus_scan_result: ActiveStorage::VirusScanner::SAFE)
      create(:attestation, :with_pdf, dossier:).pdf.blob.update!(byte_size: 2, virus_scan_result: ActiveStorage::VirusScanner::SAFE)
    end

    context 'without export template' do
      let(:export_template) { nil }

      it { expect(export.compute_estimated_files_size).to eq(ExportedFilesSizeConcern::DOSSIER_PDF_WEIGHT + 10 + 20 + 1 + 2) }
    end

    context 'with an export template' do
      let(:export_template) do
        build(:export_template, groupe_instructeur: procedure.defaut_groupe_instructeur).tap do |template|
          template.export_pdf = ExportItem.default(prefix: 'export', enabled: false)
          template.attestation = ExportItem.default(prefix: 'attestation', enabled: false)
          template.pjs = [ExportItem.default(prefix: 'pj', enabled: true, stable_id: 10)]
          template.save!
        end
      end

      it 'counts only the files the template ships' do
        expect(export.compute_estimated_files_size).to eq(10)
      end
    end
  end

  describe '.dossiers_for_export' do
    let!(:procedure) { create(:procedure, :published, :with_instructeur) }

    let!(:dossier_brouillon) { create(:dossier, :brouillon, procedure: procedure) }
    let!(:dossier_en_construction) { create(:dossier, :en_construction, procedure: procedure) }
    let!(:dossier_en_instruction) { create(:dossier, :en_instruction, procedure: procedure) }
    let!(:dossier_accepte) { create(:dossier, :accepte, procedure: procedure) }

    let(:export) do
      groupe_instructeurs = [procedure.groupe_instructeurs.first]
      user_profile = groupe_instructeurs.first.instructeurs.first

      Export.find_or_create_fresh_export(
        :csv,
        groupe_instructeurs,
        user_profile,
        procedure_presentation:,
        statut:
      )
    end

    context 'without procedure_presentation or since' do
      let(:procedure_presentation) { nil }
      let(:statut) { nil }
      it 'does not includes brouillons' do
        expect(export.send(:dossiers_for_export)).to include(dossier_en_construction)
        expect(export.send(:dossiers_for_export)).to include(dossier_en_instruction)
        expect(export.send(:dossiers_for_export)).to include(dossier_accepte)
        expect(export.send(:dossiers_for_export)).not_to include(dossier_brouillon)
      end
    end

    context 'with procedure_presentation and statut tous and filter en_construction' do
      let(:statut) { 'tous' }

      let(:procedure_presentation) do
        statut_column = procedure.dossier_state_column
        en_construction_filter = FilteredColumn.new(column: statut_column, filter: 'en_construction')
        create(:procedure_presentation,
               procedure:,
               assign_to: procedure.groupe_instructeurs.first.assign_tos.first,
               tous_filters: [en_construction_filter])
      end

      before do
        # ensure the export is generated
        export

        # change the procedure presentation
        procedure_presentation.update(tous_filters: [])
      end

      it 'only includes the en_construction' do
        expect(export.send(:dossiers_for_export)).to eq([dossier_en_construction])
      end
    end
  end

  describe '.for_groupe_instructeurs' do
    let!(:groupe_instructeur1) { create(:groupe_instructeur) }
    let!(:groupe_instructeur2) { create(:groupe_instructeur) }
    let!(:groupe_instructeur3) { create(:groupe_instructeur) }

    let!(:export1) { create(:export, groupe_instructeurs: [groupe_instructeur1, groupe_instructeur2]) }
    let!(:export2) { create(:export, groupe_instructeurs: [groupe_instructeur2]) }
    let!(:export3) { create(:export, groupe_instructeurs: [groupe_instructeur3]) }

    it 'returns exports for the specified groupe instructeurs' do
      expect(Export.for_groupe_instructeurs([groupe_instructeur1.id, groupe_instructeur2.id]))
        .to match_array([export1, export2])
    end

    it 'does not return exports not associated with the specified groupe instructeurs' do
      expect(Export.for_groupe_instructeurs([groupe_instructeur1.id])).not_to include(export2, export3)
    end

    it 'returns unique exports even if they belong to multiple matching groupe instructeurs' do
      results = Export.for_groupe_instructeurs([groupe_instructeur1.id, groupe_instructeur2.id])
      expect(results.count).to eq(2)
    end

    it 'does not returns export including more than the specified groupe instructeurs' do
      expect(Export.for_groupe_instructeurs([groupe_instructeur2.id])).to eq([export2])
    end
  end

  describe '.dossiers_count' do
    let(:export) { create(:export, :pending) }

    before do
      blob_double = instance_double("ActiveStorage::Blob", signed_id: "some_signed_id_value")
      attachment_double = instance_double("ActiveStorage::Attached::One", attach: true)

      allow(export).to receive(:blob).and_return(blob_double)
      allow(export).to receive(:file).and_return(attachment_double)

      create_list(:dossier, 3, :en_construction, groupe_instructeur: export.groupe_instructeurs.first)
    end

    it 'is not set until generation' do
      expect(export.dossiers_count).to be_nil
    end

    it 'is persisted after generation' do
      export.compute_with_safe_stale_for_purge do
        export.compute
      end

      export.reload
      expect(export.dossiers_count).to eq(3)
    end
  end
end
