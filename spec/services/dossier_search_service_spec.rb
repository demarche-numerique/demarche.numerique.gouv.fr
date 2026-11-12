# frozen_string_literal: true

describe DossierSearchService do
  describe '#matching_dossiers' do
    let!(:dossiers) { Dossier.where(id: dossier.id) }

    before { perform_enqueued_jobs(only: DossierIndexSearchTermsJob) }

    def searching(terms, with_annotations: false)
      described_class.matching_dossiers(dossiers, terms, with_annotations:)
    end

    describe 'ignores brouillon' do
      let(:dossier) { create(:dossier, state: :brouillon) }

      it { expect(searching(dossier.id.to_s)).to eq([]) }
    end

    context 'with a dossier not in brouillon' do
      let(:user) { create(:user, email: 'nicolas@email.com') }
      let(:etablissement) { create(:etablissement, entreprise_raison_sociale: 'Direction Interministerielle Du Numérique', siret: '13002526500013') }
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }], private_type_de_champs: [{ type: :text }]) }
      let(:dossier) do
        create(:dossier, procedure:, state: :en_construction, user:, etablissement:).tap do |dossier|
          dossier.public_root_champs.first.update!(value: 'Hélène mange des pommes')
          dossier.private_root_champs.first.update!(value: 'annotations')
        end
      end

      it do
        expect(searching('')).to eq([])

        # by dossier id
        expect(searching(dossier.id.to_s)).to eq([dossier.id])

        # annotations is unsearchable by default
        expect(searching('annotations')).to eq([])
        # but can be searched with the with_annotations option
        expect(searching('annotations', with_annotations: true)).to eq([dossier.id])
        # terms are ANDed across the public and private parts, which only works
        # if both are indexed as a single document
        expect(searching('pommes annotations', with_annotations: true)).to eq([dossier.id])

        # by email
        expect(searching('nicolas@email.com')).to eq([dossier.id])
        expect(searching('nicolas')).to eq([dossier.id])

        # by SIRET
        expect(searching('13002526500013')).to eq([dossier.id])
        expect(searching('1300')).to eq([dossier.id])

        # by raison sociale
        expect(searching('Direction Interministerielle Du Numérique')).to eq([dossier.id])
        expect(searching('Direction')).to eq([dossier.id])

        # with multiple terms
        expect(searching('Direction nicolas')).to eq([dossier.id])

        # with forbidden characters
        expect(searching("'?\\:&!(Direction) <Interministerielle>")).to eq([dossier.id])

        # with a single forbidden character should not crash postgres
        expect(searching('? Direction')).to eq([dossier.id])

        # with supirious spaces
        expect(searching("  nicolas  ")).to eq([dossier.id])

        # with wrong case
        expect(searching('direction')).to eq([dossier.id])

        # by champ text
        expect(searching('Hélène')).to eq([dossier.id])

        # by singular
        expect(searching('la pomme')).to eq([dossier.id])

        # without accent
        expect(searching('helene')).to eq([dossier.id])

        # NOT WORKING YET
        # with a single faulty character
        expect(searching('des pammes')).to eq([])
      end
    end

    describe 'does not ignore archived dossiers' do
      let(:dossier) { create(:dossier, state: :en_construction, archived: true) }

      it { expect(searching(dossier.id.to_s)).to eq([dossier.id]) }
    end

    describe 'caps full-text results to MAX_RESULTS' do
      let(:user) { create(:user, email: 'martin@email.com') }
      let(:dossier) { create(:dossier, state: :en_construction, user:) }
      let(:dossier_2) { create(:dossier, state: :en_construction, user:) }
      let!(:dossiers) { Dossier.where(id: [dossier.id, dossier_2.id]) }

      before { stub_const('DossierSearchService::MAX_RESULTS', 1) }

      it { expect(searching('martin').size).to eq(1) }
    end
  end

  describe '#matching_dossiers_for_user' do
    let(:user) { create(:user) }
    let(:another_user) { create(:user) }

    def searching(terms, user) = described_class.matching_dossiers_for_user(terms, user)

    context 'when the dossier is brouillon' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }], private_type_de_champs: [{ type: :text }]) }
      let!(:dossier) do
        create(:dossier, procedure:, state: :brouillon, user:).tap do |dossier|
          dossier.public_root_champs.first.update!(value: 'pommes')
          dossier.private_root_champs.first.update!(value: 'annotations')
        end
      end

      before { perform_enqueued_jobs(only: DossierIndexSearchTermsJob) }

      it do
        # searching its own dossier by id
        expect(searching(dossier.id.to_s, user)).to eq([dossier])

        # searching another dossier by id
        expect(searching(dossier.id.to_s, another_user)).to eq([])

        expect(searching('pommes', user)).to eq([dossier])

        # annotations is unsearchable
        expect(searching('annotations', user)).to eq([])
      end
    end

    context 'when the user is invited on the dossier' do
      let(:dossier) { create(:dossier) }

      before { create(:invite, dossier:, user:) }

      it { expect(searching(dossier.id.to_s, user)).to eq([dossier]) }
    end

    context 'when the full-text result is merged into a query that joins dossiers twice' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }
      let!(:dossier) do
        create(:dossier, procedure:, state: :en_construction, user:).tap do |dossier|
          dossier.public_root_champs.first.update!(value: 'pommes')
        end
      end

      it 'qualifies the tsvector column so it does not raise PG::AmbiguousColumn' do
        self_joined = Dossier
          .joins('INNER JOIN dossiers d2 ON d2.id = dossiers.id')
          .merge(searching('pommes', user))

        expect { self_joined.to_a }.not_to raise_error
      end
    end
  end

  describe '.to_tsquery' do
    # `:*` makes each term a prefix match, `&` joins them.
    it 'builds a prefix matching query out of the terms' do
      expect(described_class.to_tsquery('Direction nicolas')).to eq('Direction:* & nicolas:*')
    end

    # `& | ! ( ) : <` are tsquery operators and must go, or to_tsquery raises.
    it 'drops the characters postgres would parse instead of matching' do
      expect(described_class.to_tsquery('Dupont & Fils (13)')).to eq('Dupont:* & Fils:* & 13:*')
    end

    it 'drops quotes too, so an injection payload lands as plain terms' do
      expect(described_class.to_tsquery("Dupont') OR 1=1--")).to eq('Dupont:* & OR:* & 1=1--:*')
    end
  end
end
