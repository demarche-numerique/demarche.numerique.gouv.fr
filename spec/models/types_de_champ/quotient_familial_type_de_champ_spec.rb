# frozen_string_literal: true

describe TypesDeChamp::QuotientFamilialTypeDeChamp do
  describe '#champ_blank?' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :quotient_familial }]) }
    let(:tdc_quotient_familial) { procedure.active_revision.types_de_champ.first }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }

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
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :quotient_familial, libelle: 'qf' }]) }
    let(:tdc_quotient_familial) { procedure.active_revision.types_de_champ.first }
    let(:columns) { tdc_quotient_familial.columns(procedure:) }

    it 'adds QF columns' do
      expected_columns = [
        "qf – [Allocataire 1] Nom de naissance",
        "qf – [Allocataire 1] Prénoms",
        "qf – [Allocataire 2] Nom de naissance",
        "qf – [Allocataire 2] Prénoms",
        "qf – Valeur du QF",
        "qf – Mois du QF",
        "qf – Année du QF",
      ]

      expect(columns.map(&:label)).to match_array(expected_columns)
    end
  end
end
