# frozen_string_literal: true

describe APIEntreprise::RNAAdapter do
  let(:procedure) { create(:procedure) }
  let(:procedure_id) { procedure.id }

  subject { adapter.to_params }

  context 'given an RNA' do
    let(:adapter) { described_class.new(rna, procedure_id) }
    let(:rna) { 'W111111111' }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{rna}/)
        .to_return(body: body, status: status)
    end
    context 'when rna is not valid' do
      let(:rna) { '234567' }
      let(:body) { '' }
      let(:status) { 404 }

      it { is_expected.to eq({}) }
    end

    context "when responds with valid schema" do
      let(:body) { File.read('spec/fixtures/files/api_entreprise/associations.json') }
      let(:status) { 200 }

      it '#to_params return valid hash' do
        expect(subject).to be_an_instance_of(Hash)
        expect(subject["association_rna"]).to eq("W751080001")
        expect(subject["association_titre"]).to eq("LA PRÉVENTION ROUTIERE")
        expect(subject["association_objet"]).to eq("L'association a pour objet de promouvoir la pratique du sport de haut niveau et de contribuer à la formation des jeunes sportifs.")
        expect(subject["association_date_declaration"]).to eq("2019-01-01")
        expect(subject["association_date_publication"]).to eq("2018-01-01")
        expect(subject["adresse"]).to eq({
          complement: "",
          numero_voie: "33",
          type_voie: "rue",
          libelle_voie: "de Modagor",
          distribution: "dummy",
          code_insee: "75108",
          code_postal: "75009",
          commune: "Paris",
        })
      end
    end
  end

  context 'given a SIRET' do
    let(:siret) { '97948505900013' }
    let(:siren) { siret[0..8] }
    let(:adapter) { described_class.new(siret, procedure_id) }

    let(:body) { File.read('spec/fixtures/files/api_entreprise/associations.json') }
    let(:status) { 200 }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{siren}\?/)
        .to_return(body: body, status: status)
    end

    it '#to_params return valid hash' do
      expect(subject).to be_an_instance_of(Hash)
      expect(subject["association_rna"]).to eq("W751080001")
      expect(subject["association_titre"]).to eq("LA PRÉVENTION ROUTIERE")
      expect(subject["association_objet"]).to eq("L’association a pour objet de promouvoir la pratique du sport de haut niveau et de contribuer à la formation des jeunes sportifs.")
      expect(subject["association_date_declaration"]).to eq("2019-01-01")
      expect(subject["association_date_publication"]).to eq("2018-01-01")
      expect(subject["adresse"]).to eq({
        complement: "",
        numero_voie: "33",
        type_voie: "rue",
        libelle_voie: "de Modagor",
        distribution: "dummy",
        code_insee: "75108",
        code_postal: "75009",
        commune: "Paris",
      })
    end
  end
end
