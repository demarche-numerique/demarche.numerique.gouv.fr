# frozen_string_literal: true

describe TypesDeChamp::FranceConnectTypeDeChamp do
  describe '#max_file_size_bytes' do
    it 'caps the fallback justificatif like a pièce justificative' do
      expect(build(:type_de_champ_quotient_familial).max_file_size_bytes).to eq(200.megabytes)
    end
  end

  context "when type de champ is quotient_famiilial" do
    describe '#champ_blank?' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :quotient_familial }]) }
      let(:tdc_quotient_familial) { procedure.active_revision.type_de_champs.first }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }

      subject { tdc_quotient_familial.champ_blank?(champ) }

      context 'when data have been fetched but the user has not confirmed its accuracy' do
        before { champ.update(external_state: 'fetched') }

        it 'returns true' do
          expect(subject).to eq(true)
        end
      end

      context 'when data have been fetched and the user has confirmed its accuracy' do
        before { champ.update(external_state: 'fetched', value: 'true') }

        it 'returns false' do
          expect(subject).to eq(false)
        end
      end

      context 'when data have been recovered but the user has indicated that the data is incorrect' do
        before { champ.update(external_state: 'fetched', value: 'false') }

        it 'returns true if he has uploaded an attachment' do
          champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
          expect(subject).to eq(false)
        end
      end

      context 'when data have not been recovered' do
        before { champ.update(external_state: 'idle') }

        it 'returns true if the user has uploaded an attachment' do
          champ.piece_justificative_file.attach(fixture_file_upload('spec/fixtures/files/logo_test_procedure.png', 'image/png'))
          expect(subject).to eq(false)
        end
      end
    end

    describe '#columns' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :quotient_familial, libelle: 'qf' }]) }
      let(:tdc_quotient_familial) { procedure.active_revision.type_de_champs.first }
      let(:columns) { tdc_quotient_familial.columns(procedure_id: procedure.id) }

      it 'adds QF columns' do
        expected_columns = [
          "qf – [Allocataire 1] Nom de naissance",
          "qf – [Allocataire 1] Prénoms",
          "qf – [Allocataire 2] Nom de naissance",
          "qf – [Allocataire 2] Prénoms",
          "qf – Valeur du QF",
          "qf – Période du QF",
        ]

        expect(columns.map(&:label)).to match_array(expected_columns)
      end
    end
  end

  context "when type de champ is etudiant_boursier" do
    describe '#columns' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :etudiant_boursier, libelle: 'eb' }]) }
      let(:tdc_etudiant_boursier) { procedure.active_revision.type_de_champs.first }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }

      before do
        champ.update(
          external_state: 'fetched',
          value: 'true',
          value_json: { api_part: { statut_boursier: { est_boursier: true, est_radie: false } } }
        )
      end

      def column_value(label)
        tdc_etudiant_boursier.columns(procedure_id: procedure.id).find { it.label == label }.value(champ)
      end

      it 'extracts values nested under statut_boursier' do
        expect(column_value('eb – Boursier')).to be(true)
        expect(column_value('eb – Radié')).to be(false)
      end

      describe 'a boolean column' do
        let(:column) { tdc_etudiant_boursier.columns(procedure_id: procedure.id).find { it.label == 'eb – Boursier' } }
        let(:dossiers) { Dossier.where(id: dossier.id) }

        def filtering(value) = column.filtered_ids(dossiers, { operator: 'match', value: })

        # value_json stores a JSON boolean, which like_regex can never match:
        # the filter needs a @ == true / @ == false comparison.
        it 'filters on the stored boolean' do
          expect(filtering(['true'])).to eq([dossier.id])
          expect(filtering(['false'])).to eq([])
        end

        it 'ignores a value the radio buttons cannot produce' do
          expect(filtering(['nimp'])).to eq([dossier.id])
        end

        # Radio buttons are built from options_for_select: without options the
        # filter renders an empty radio list, no value can even be picked.
        it 'offers oui/non options to build the radio buttons from' do
          expect(column.options_for_select).to eq([['oui', true], ['non', false]])
        end
      end
    end
  end
end
