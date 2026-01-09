# frozen_string_literal: true

describe APIEntreprise::EntrepriseAdapter do
  let(:siren) { '130025265' }
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }
  let(:adapter) { described_class.new(siren, procedure_id) }
  subject { adapter.to_params }

  before do
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/unites_legales\/#{siren}/)
      .to_return(body: body, status: status)
    allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
  end

  context "when the SIRET is valid" do
    let(:body) { File.read('spec/fixtures/files/api_entreprise/entreprises.json') }
    let(:status) { 200 }

    it '#to_params class est une Hash ?' do
      expect(subject).to be_an_instance_of(Hash)
    end

    context 'Attributs Entreprises' do
      it 'L’entreprise contient bien un siren' do
        expect(subject[:entreprise_siren]).to eq(siren)
      end

      it 'L’entreprise contient bien une forme_juridique' do
        expect(subject[:entreprise_forme_juridique]).to eq("Service central d’un ministère")
      end

      it 'L’entreprise contient bien un forme_juridique_code' do
        expect(subject[:entreprise_forme_juridique_code]).to eq('7120')
      end

      it 'L’entreprise contient bien une raison_sociale' do
        expect(subject[:entreprise_raison_sociale]).to eq('DIRECTION INTERMINISTERIELLE DU NUMERIQUE')
      end

      it 'L’entreprise contient bien un siret_siege_social' do
        expect(subject[:entreprise_siret_siege_social]).to eq('13002526500013')
      end

      it 'L’entreprise contient bien un code_effectif_entreprise' do
        expect(subject[:entreprise_code_effectif_entreprise]).to eq('51')
      end

      it 'L’entreprise contient bien une date_creation' do
        expect(subject[:entreprise_date_creation].to_i).to eq(1634103818)
      end

      it 'L’entreprise contient bien un etat administratif' do
        expect(subject[:entreprise_etat_administratif]).to eq('actif')
      end
    end

    context "when date_creation is empty" do
      let(:body) do
        hash = JSON.parse(super())
        hash["data"]["date_creation"] = nil
        JSON.generate(hash)
      end

      it 'L’entreprise ne contient pas de date_creation' do
        expect(subject[:entreprise_date_creation]).to be_nil
      end
    end
  end

  context "when the SIRET is unknown" do
    let(:body) { File.read('spec/fixtures/files/api_entreprise/entreprises_not_found.json') }
    let(:status) { 404 }

    it '#to_params class est une Hash ?' do
      expect(subject).to eq({})
    end
  end

  context "when the service is unavailable" do
    let(:body) { File.read('spec/fixtures/files/api_entreprise/entreprises_unavailable.json') }
    let(:status) { 500 }

    it 'raises an exception' do
      expect { subject }.to raise_error(APIEntreprise::API::Error::RequestFailed)
    end
  end

  context "when individual" do
    let(:siren) { '909700890' }
    let(:body) { File.read('spec/fixtures/files/api_entreprise/entreprise_individual.json') }
    let(:status) { 200 }

    it 'L’entreprise contient bien un forme_juridique_code' do
      expect(subject[:entreprise_forme_juridique_code]).to eq('1000')
    end

    # Suppression du champ raison_sociale pour les personnes physiques
    # en v3
    # https://entreprise.api.gouv.fr/developpeurs/guide-migration
    it 'L’entreprise ne contient pas de raison_sociale' do
      expect(subject[:entreprise_raison_sociale]).to be_nil
    end

    it 'L’entreprise contient bien un nom' do
      expect(subject[:entreprise_nom]).to eq('LE LOUARN SMAIL (LE LOUARN)')
    end

    it 'L’entreprise contient bien un prenom' do
      expect(subject[:entreprise_prenom]).to eq('MARINE')
    end
  end
end
