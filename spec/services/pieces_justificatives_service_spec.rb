# frozen_string_literal: true

describe PiecesJustificativesService do
  describe 'pjs_for_champs' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative, mandatory: false }, { type: :repetition, mandatory: false, children: [{ type: :piece_justificative, mandatory: false }] }]) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:dossiers) { Dossier.where(id: dossier.id) }
    let(:witness) { create(:dossier, procedure: procedure) }
    let(:export_template) { double('ExportTemplate') }
    let(:pj_service) { PiecesJustificativesService.new(user_profile:, export_template:) }
    let(:user_profile) { build(:administrateur) }

    def pj_champ(d) = d.project_champs_public.find(&:piece_justificative?)
    def repetition(d) = d.project_champs_public.find(&:repetition?)
    def attachments(champ) = champ.piece_justificative_file.attachments

    before { attach_file_to_champ(pj_champ(witness)) }

    subject { pj_service.send(:pjs_for_champs, dossiers) }

    context 'without any attachment' do
      it { expect(subject).to be_empty }
    end

    context 'with a single attachment' do
      let(:champ) { pj_champ(dossier) }
      before { attach_file_to_champ(champ) }

      it do
        expect(export_template).to receive(:attachment_path)
          .with(dossier, attachments(pj_champ(dossier)).first, index: 0, row_index: nil, champ:)
        subject
      end
    end

    context 'with multiple attachments' do
      let(:champ) { pj_champ(dossier) }

      before do
        attach_file_to_champ(champ)
        attach_file_to_champ(champ)
      end

      it do
        expect(export_template).to receive(:attachment_path)
          .with(dossier, attachments(pj_champ(dossier)).first, index: 0, row_index: nil, champ:)

        expect(export_template).to receive(:attachment_path)
          .with(dossier, attachments(pj_champ(dossier)).second, index: 1, row_index: nil, champ:)
        subject
      end
    end

    context 'with a repetition' do
      let(:first_champ) { champ_for_update(repetition(dossier).rows.first.first) }
      let(:second_champ) { champ_for_update(repetition(dossier).rows.second.first) }

      before do
        repetition(dossier).add_row(updated_by: 'test')
        repetition(dossier).add_row(updated_by: 'test')
        attach_file_to_champ(first_champ)
        attach_file_to_champ(first_champ)
        attach_file_to_champ(second_champ)
      end

      it do
        first_child_attachments = attachments(first_champ)
        second_child_attachments = attachments(second_champ)

        expect(export_template).to receive(:attachment_path)
          .with(dossier, first_child_attachments.first, index: 0, row_index: 0, champ: first_champ)

        expect(export_template).to receive(:attachment_path)
          .with(dossier, first_child_attachments.second, index: 1, row_index: 0, champ: first_champ)

        expect(export_template).to receive(:attachment_path)
          .with(dossier, second_child_attachments.first, index: 0, row_index: 1, champ: second_champ)

        DossierPreloader.new(dossiers).all
        count = 0

        callback = lambda { |*_args| count += 1 }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          subject
        end

        expect(count).to eq(0)
      end
    end
  end

  describe '.liste_documents' do
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:dossiers) { Dossier.where(id: dossier.id) }
    let(:default_export_template) { build(:export_template, groupe_instructeur: procedure.defaut_groupe_instructeur) }
    let(:export_template) { nil }
    subject do
      PiecesJustificativesService.new(user_profile:, export_template:).liste_documents(dossiers).map(&:first)
    end

    context 'no acl' do
      let(:user_profile) { build(:administrateur) }
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:witness) { create(:dossier, procedure: procedure) }
      def pj_champ(d) = d.project_champs_public.find(&:piece_justificative?)

      context 'with a single attachment' do
        before do
          attach_file_to_champ(pj_champ(dossier))
          attach_file_to_champ(pj_champ(witness))
        end

        it { expect(subject).to match_array(pj_champ(dossier).piece_justificative_file.attachments) }

        context 'with export_template' do
          let(:export_template) { build(:export_template, :enabled_pjs, groupe_instructeur: procedure.defaut_groupe_instructeur) }

          it { expect(subject).to match_array(pj_champ(dossier).piece_justificative_file.attachments) }
        end
      end

      context 'with a multiple attachments' do
        before do
          attach_file_to_champ(pj_champ(dossier))
          attach_file_to_champ(pj_champ(witness))
          attach_file_to_champ(pj_champ(dossier))
        end

        it do
          expect(subject.count).to eq(2)
          expect(subject).to match_array(pj_champ(dossier).piece_justificative_file.attachments)
        end
      end

      context 'with a pj not safe on a champ' do
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
        let(:dossier) { create(:dossier, procedure: procedure) }

        before { attach_file_to_champ(pj_champ(dossier), false) }

        it { expect(subject).to be_empty }
      end

      context 'with a identite champ pj' do
        let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :titre_identite }]) }
        let(:dossier) { create(:dossier, procedure: procedure) }

        let(:champ_identite) { dossier.project_champs_public.find(&:titre_identite?) }

        before { attach_file_to_champ(champ_identite) }

        it "doesn't return sensitive documents like titre_identite" do
          expect(champ_identite.piece_justificative_file).to be_attached
          expect(subject).to be_empty
        end

        context 'with export_template' do
          let(:export_template) { build(:export_template, :enabled_pjs, groupe_instructeur: procedure.defaut_groupe_instructeur) }

          it { expect(subject).to be_empty }
        end
      end

      context 'with a pj on an commentaire' do
        let(:dossier) { create(:dossier) }
        let(:witness) { create(:dossier) }

        let!(:commentaire) { create(:commentaire, dossier: dossier) }
        let!(:witness_commentaire) { create(:commentaire, dossier: witness) }

        before do
          attach_file(commentaire.piece_jointe)
          attach_file(witness_commentaire.piece_jointe)
        end

        it { expect(subject).to match_array(dossier.commentaires.first.piece_jointe.attachments) }

        context 'with export_template' do
          let(:export_template) { default_export_template }

          it { expect(subject).to be_empty }
        end
      end

      context 'with a pj not safe on a commentaire' do
        let(:dossier) { create(:dossier) }
        let!(:commentaire) { create(:commentaire, dossier: dossier) }

        before { attach_file(commentaire.piece_jointe, false) }

        it { expect(subject).to be_empty }
      end

      context 'with a motivation' do
        let(:dossier) { create(:dossier, :with_justificatif) }
        let!(:witness) { create(:dossier, :with_justificatif) }

        it { expect(subject).to match_array(dossier.justificatif_motivation.attachment) }

        context 'with export_template' do
          let(:export_template) { default_export_template }

          it { expect(subject).to be_empty }
        end
      end

      context 'with a motivation not safe' do
        let(:dossier) { create(:dossier) }

        before { attach_file(dossier.justificatif_motivation, false) }

        it { expect(subject).to be_empty }
      end

      context 'with an attestation' do
        let(:dossier) { create(:dossier, :accepte, :with_attestation_acceptation) }
        let!(:witness) { create(:dossier, :accepte, :with_attestation_acceptation) }

        it { expect(subject).to match_array(dossier.attestation.pdf.attachment) }
        it 'uses default name for dossier directory' do
          expect(PiecesJustificativesService.new(user_profile:, export_template: nil).liste_documents(dossiers).map(&:second)[0].starts_with?("dossier-#{dossier.id}/pieces_justificatives")).to be true
        end

        context 'with export_template' do
          let(:export_template) { default_export_template }

          it { expect(subject).to match_array(dossier.attestation.pdf.attachment) }
        end
      end

      context 'with an etablissement' do
        let(:dossier) { create(:dossier, :with_entreprise) }
        let(:attestation_sociale) { dossier.etablissement.entreprise_attestation_sociale }
        let(:attestation_fiscale) { dossier.etablissement.entreprise_attestation_fiscale }

        let!(:witness) { create(:dossier, :with_entreprise) }
        let!(:witness_attestation_sociale) { witness.etablissement.entreprise_attestation_sociale }
        let!(:witness_attestation_fiscale) { witness.etablissement.entreprise_attestation_fiscale }

        before do
          attach_file(attestation_sociale)
          attach_file(attestation_fiscale)
        end

        it { expect(subject).to match_array([attestation_sociale.attachment, attestation_fiscale.attachment]) }

        it 'uses default name for dossier directory' do
          expect(PiecesJustificativesService.new(user_profile:, export_template: nil).liste_documents(dossiers).map(&:second)[0].starts_with?("dossier-#{dossier.id}/pieces_justificatives")).to be true
        end

        context 'with export_template' do
          let(:export_template) { default_export_template }

          it { expect(subject).to be_empty }
        end
      end
    end

    context 'acl on private pj champ' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, procedure: procedure) }
      let(:witness) { create(:dossier, procedure: procedure) }

      let!(:private_pj) { create(:type_de_champ_piece_justificative, procedure: procedure, private: true) }
      def private_pj_champ(d) = d.project_champs_private.find(&:piece_justificative?)

      before do
        attach_file_to_champ(private_pj_champ(dossier))
        attach_file_to_champ(private_pj_champ(witness))
      end

      context 'given an administrateur' do
        let(:user_profile) { build(:administrateur) }
        it { expect(subject).to match_array(private_pj_champ(dossier).piece_justificative_file.attachments) }
      end

      context 'given an instructeur' do
        let(:user_profile) { create(:instructeur) }
        it { expect(subject).to match_array(private_pj_champ(dossier).piece_justificative_file.attachments) }
      end

      context 'given an expert' do
        let(:user_profile) { create(:expert) }
        it { expect(subject).not_to match_array(private_pj_champ(dossier).piece_justificative_file.attachments) }
      end
    end

    context 'acl on bill' do
      let(:dossier) { create(:dossier) }
      let(:witness) { create(:dossier) }
      let(:default_export_template) { build(:export_template, groupe_instructeur: dossier.procedure.defaut_groupe_instructeur) }

      let(:bill_signature) do
        bs = build(:bill_signature, :with_serialized, :with_signature)
        bs.save(validate: false)
        bs
      end

      let(:witness_bill_signature) do
        bs = build(:bill_signature, :with_serialized, :with_signature)
        bs.save(validate: false)
        bs
      end

      before do
        create(:dossier_operation_log, dossier: dossier, bill_signature: bill_signature)
        create(:dossier_operation_log, dossier: witness, bill_signature: witness_bill_signature)
      end

      let(:dossier_bs) { dossier.dossier_operation_logs.first.bill_signature }

      context 'given an Administrateur, includes bills' do
        let(:user_profile) { build(:administrateur) }

        it "returns serialized bill and signature" do
          expect(subject).to match_array([dossier_bs.serialized.attachment, dossier_bs.signature.attachment])
        end

        context 'with export_template' do
          let(:export_template) { default_export_template }

          it { expect(subject).to be_empty }
        end

        context 'with a dol' do
          let(:dol) { create(:dossier_operation_log, dossier: dossier) }
          let(:witness_dol) { create(:dossier_operation_log, dossier: witness) }

          before do
            attach_file(dol.serialized)
            attach_file(witness_dol.serialized)
          end

          it { expect(subject).to include(dol.serialized.attachment) }

          context 'with export_template' do
            let(:export_template) { default_export_template }

            it { expect(subject).to be_empty }
          end
        end
      end

      context 'given an expert, does not includes bills' do
        let(:user_profile) { create(:expert) }

        it { expect(subject).to be_empty }
      end

      context 'given an instructeur, does not includes bills' do
        let(:user_profile) { create(:instructeur) }

        it { expect(subject).to be_empty }
      end
    end

    context 'acl on with_avis_piece_justificative' do
      let(:user_profile) { create(:expert) }
      let(:procedure) { create(:procedure) }
      let(:dossier) { create(:dossier, procedure: procedure) }

      context 'with avis.piece_justificative being confidentiel' do
        let(:procedure) { create(:procedure) }
        let(:avis) { create(:avis, dossier: dossier, confidentiel: true) }

        before do
          to_be_attached = {
            io: StringIO.new("toto"),
            filename: "toto.png",
            content_type: "image/png",
            metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE },
          }

          avis.piece_justificative_file.attach(to_be_attached)
          avis.introduction_file.attach(avis.piece_justificative_file.blob)
        end

        context 'given an administrateur' do
          let(:user_profile) { build(:administrateur) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end

          context 'with export_template' do
            let(:export_template) { default_export_template }

            it { expect(subject).to be_empty }
          end
        end

        context 'given an instructeur' do
          let(:user_profile) { create(:instructeur) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end
        end

        context 'given an expert' do
          let(:user_profile) { create(:expert) }
          it "doesn't return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(0)
          end
        end

        context 'when the expert has given the avis' do
          let(:experts_procedure) { create(:experts_procedure, expert: user_profile, procedure:) }
          let(:avis) { create(:avis, experts_procedure:, dossier: dossier, confidentiel: true) }
          let(:user_profile) { create(:expert) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end
        end
      end

      context 'with avis.piece_justificative being public' do
        let(:procedure) { create(:procedure) }
        let(:dossier) { create(:dossier, procedure: procedure) }
        let(:avis) { create(:avis, dossier: dossier, confidentiel: false) }
        before do
          to_be_attached = {
            io: StringIO.new("toto"),
            filename: "toto.png",
            content_type: "image/png",
            metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE },
          }

          avis.piece_justificative_file.attach(to_be_attached)
          avis.introduction_file.attach(avis.piece_justificative_file.blob)
        end

        context 'given an administrateur' do
          let(:user_profile) { build(:administrateur) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end
        end

        context 'given an instructeur' do
          let(:user_profile) { create(:instructeur) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end
        end

        context 'given an expert' do
          let(:user_profile) { create(:expert) }
          it "return confidentiel avis.piece_justificative_file" do
            expect(subject.size).to eq(2)
          end
        end
      end
    end
  end

  describe '.generate_dossiers_export' do
    let(:user_profile) { build(:administrateur) }
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :repetition, children: [{ type: :piece_justificative }] }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure: procedure) }
    let(:dossiers) { Dossier.where(id: dossier.id) }
    let(:export_template) { nil }
    subject { PiecesJustificativesService.new(user_profile:, export_template:).generate_dossiers_export(dossiers) }

    it "doesn't update dossier" do
      expect { subject }.not_to change { dossier.updated_at }
    end

    context 'when given an expert' do
      let!(:user_profile) { create(:expert) }
      let!(:confidentiel_avis) { create(:avis, :confidentiel, dossier: dossier) }
      let!(:not_confidentiel_avis) { create(:avis, :not_confidentiel, dossier: dossier) }
      let!(:expert_avis) { create(:avis, :confidentiel, dossier: dossier, expert: user_profile) }

      subject { PiecesJustificativesService.new(user_profile:, export_template:).generate_dossiers_export(dossiers) }
      it "includes avis not confidentiel as well as expert's avis" do
        expect_any_instance_of(Dossier).to receive(:avis_for_expert).with(user_profile).and_return([])
        subject
      end

      it 'gives default name to export pdf file' do
        expect(subject.first.second.starts_with?("dossier-#{dossier.id}/export-#{dossier.id}")).to eq true
      end
    end

    context 'with export template' do
      let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }
      let(:export_template) { create(:export_template, groupe_instructeur:, dossier_folder: ExportItem.default(prefix: 'DOSSIER')) }
      subject { PiecesJustificativesService.new(user_profile:, export_template:).generate_dossiers_export(dossiers) }

      it 'gives custom name to export pdf file' do
        expect(subject.first.second).to eq "DOSSIER-#{dossier.id}/export-#{dossier.id}.pdf"
      end

      context 'when export pdf is disabled' do
        let(:export_template) { create(:export_template, groupe_instructeur:, export_pdf: ExportItem.default(prefix: 'export', enabled: false)) }

        it 'does not export pdf' do
          expect(subject).to be_empty
        end
      end
    end
  end

  describe '#compute_champ_id_row_index' do
    let(:user_profile) { build(:administrateur) }
    let(:types_de_champ_public) do
      [
        { type: :repetition, mandatory: false, children: [{ type: :piece_justificative }] },
        { type: :repetition, mandatory: false, children: [{ type: :piece_justificative }, { type: :piece_justificative }] },
      ]
    end

    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier_1) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champs) { dossier_1.filled_champs }

    def repetition(d, index:) = d.project_champs_public.filter(&:repetition?)[index]

    subject { PiecesJustificativesService.new(user_profile:, export_template: nil).send(:compute_champ_id_row_index, champs) }

    before do
      # repet_0 (stable_id: r0)
      # # row_0
      # # # pj_champ_0 (stable_id: 0)
      # # row_1
      # # # pj_champ_1 (stable_id: 0)
      # repet_1 (stable_id: r1)
      # # row_0
      # # # pj_champ_2 (stable_id: 1)
      # # # pj_champ_3 (stable_id: 2)
      # # row_1
      # # # pj_champ_4 (stable_id: 1)
      # # # pj_champ_5 (stable_id: 2)

      repet_0 = repetition(dossier_1, index: 0)
      repet_1 = repetition(dossier_1, index: 1)

      repet_0.add_row(updated_by: 'test')
      repet_0.add_row(updated_by: 'test')

      repet_1.add_row(updated_by: 'test')
      repet_1.add_row(updated_by: 'test')
    end

    it do
      champs = dossier_1.project_champs_public
      repet_0 = champs[0]
      pj_0 = repet_0.rows.first.first
      pj_1 = repet_0.rows.second.first

      repet_1 = champs[1]
      pj_2 = repet_1.rows.first.first
      pj_3 = repet_1.rows.first.second

      pj_4 = repet_1.rows.second.first
      pj_5 = repet_1.rows.second.second

      is_expected.to eq({ pj_0.id => 0, pj_1.id => 1, pj_2.id => 0, pj_3.id => 0, pj_4.id => 1, pj_5.id => 1 })
    end
  end

  def attach_file_to_champ(champ, safe = true)
    champ = champ_for_update(champ)
    attach_file(champ.piece_justificative_file, safe)
    champ.save!
  end

  def attach_file(attachable, safe = true)
    to_be_attached = {
      io: StringIO.new("toto"),
      filename: "toto.png", content_type: "image/png",
    }

    if safe
      to_be_attached[:metadata] = { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
    end

    attachable.attach(to_be_attached)
  end
end
