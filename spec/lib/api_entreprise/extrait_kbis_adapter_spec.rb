# frozen_string_literal: true

describe APIEntreprise::ExtraitKbisAdapter do
  let(:siren) { '130025265' }
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }
  let(:adapter) { described_class.new(siren, procedure_id) }
  subject { adapter.to_params }

  before do
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/infogreffe\/rcs\/unites_legales\/#{siren}\/extrait_kbis/)
      .to_return(body: body, status: status)
    allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
  end
  context "when the SIRET is valid" do
    let(:body) { File.read('spec/fixtures/files/api_entreprise/extrait_kbis.json') }
    let(:status) { 200 }

    it '#to_params class est une Hash ?' do
      expect(subject).to be_an_instance_of(Hash)
    end

    it 'L’entreprise contient bien un capital_social' do
      expect(subject[:entreprise_capital_social]).to eq(50123.6)
    end

    it 'L’entreprise contient bien un nom_commercial' do
      expect(subject[:entreprise_nom_commercial]).to eq('DECATHLON')
    end
  end
end
