# frozen_string_literal: true

describe Zone do
  let(:now) { Time.zone.parse("2022-08-11") }
  before do
    travel_to(now)
  end

  after do
  end

  describe '#label' do
    let(:start_previous_government) { Date.parse('2020-07-06') }
    let(:start_last_government) { Date.parse('2022-05-20') }
    let(:zone) do
      create(:zone, labels: [
        {
          designated_on: start_previous_government,
          name: "Ministère de l’Économie, des Finances et de la Relance",
        },
        {
          designated_on: start_last_government,
          name: "Ministère de l’Économie, des Finances et de la Souveraineté industrielle et numérique",
        },
      ])
    end

    it 'returns label for the current millesime' do
      expect(zone.current_label).to eq "Ministère de l’Économie, des Finances et de la Souveraineté industrielle et numérique"
    end

    it 'returns label at specific date' do
      expect(zone.label_at(start_previous_government + 1.week)).to eq "Ministère de l’Économie, des Finances et de la Relance"
      expect(zone.label_at(start_last_government + 1.week)).to eq "Ministère de l’Économie, des Finances et de la Souveraineté industrielle et numérique"
      expect(zone.label_at(start_previous_government - 1.week)).to eq "Ministère de l’Économie, des Finances et de la Relance"
    end
  end

  describe "#available_at?" do
    let(:start_previous_government) { Date.parse('2020-07-06') }
    let(:start_last_government) { Date.parse('2022-05-20') }
    let(:start_futur_government) { Date.parse('2027-05-20') }
    let(:zone) do
      create(:zone, labels: [
        {
          designated_on: start_previous_government,
          name: "Ministère des Outre-mer",
        },
        {
          designated_on: start_last_government,
          name: "Non attribué",
        },
        {
          designated_on: start_futur_government,
          name: "Ministère des Territoires d'Outre-mer",
        },
      ])
    end

    it "returns false if the zone does'nt exist at a specific date" do
      expect(zone.available_at?(start_last_government + 1.week)).to be_falsy
    end

    it "returns true if the zone exist at a specific date" do
      expect(zone.available_at?(start_futur_government + 1.week)).to be_truthy
      expect(zone.available_at?(start_previous_government + 1.week)).to be_truthy
    end
  end

  describe "#self.available_at?" do
    let(:start_previous_government) { Date.parse('2020-07-06') }
    let(:start_last_government) { Date.parse('2022-05-20') }
    let(:start_futur_government) { Date.parse('2027-05-20') }
    let(:om) do
      create(:zone, labels: [
        {
          designated_on: start_previous_government,
          name: "Ministère des Outre-mer",
        },
        {
          designated_on: start_last_government,
          name: "Non attribué",
        },
        {
          designated_on: start_futur_government,
          name: "Ministère des Territoires d'Outre-mer",
        },
      ])
    end

    let!(:culture) do
      create(:zone, labels: [
        {
          designated_on: start_previous_government,
          name: "Ministère de la Culture",
        },
      ])
    end

    let!(:om) do
      create(:zone, labels: [
        {
          designated_on: start_previous_government,
          name: "Ministère des Outre-mer",
        },
        {
          designated_on: start_last_government,
          name: "Non attribué",
        },
        {
          designated_on: start_futur_government,
          name: "Ministère des Territoires d'Outre-mer",
        },
      ])
    end

    it 'returns only available zones at specific date' do
      expect(Zone.available_at(start_last_government + 1.day).map(&:label)).to eq ["Ministère de la Culture"]
      expect(Zone.available_at(start_previous_government + 1.day).map(&:label)).to match_array(["Ministère de la Culture", "Ministère des Outre-mer"])
    end
  end

  context 'with zones' do
    before do
      create(:zone, acronym: 'MEN', tchap_hs: ['agent.education.tchap.gouv.fr'])
      create(:zone, acronym: 'ESR', tchap_hs: ['agent.education.tchap.gouv.fr'])
    end

    describe "#self.default_for" do
      it 'returns zone related to tchap hs' do
        expect(Zone.default_for('agent.education.tchap.gouv.fr').map(&:acronym)).to match_array(['MEN', 'ESR'])
        expect(Zone.default_for('agent.tchap.gouv.fr').map(&:acronym)).to eq []
      end
    end
  end
end
