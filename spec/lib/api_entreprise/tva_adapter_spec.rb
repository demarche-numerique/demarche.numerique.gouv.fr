# frozen_string_literal: true

describe APIEntreprise::TvaAdapter do
  let(:siren) { '418166096' }
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }
  let(:adapter) { described_class.new(siren, procedure_id) }
  subject { adapter.to_params }

  before do
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/european_commission\/unites_legales\/#{siren}\/numero_tva/)
      .to_return(body: body, status: status)
    allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
  end

  context "when the SIRET is valid" do
    let(:body) { File.read('spec/fixtures/files/api_entreprise/tva.json') }
    let(:status) { 200 }

    it '#to_params class est une Hash ?' do
      expect(subject).to be_an_instance_of(Hash)
    end

    it 'L’entreprise contient bien un numero_tva_intracommunautaire' do
      expect(subject[:entreprise_numero_tva_intracommunautaire]).to eq("FR48672039971")
    end
  end
end
