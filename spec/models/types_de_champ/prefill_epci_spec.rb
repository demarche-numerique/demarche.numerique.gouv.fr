# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillEpci do
  let(:procedure) { build(:procedure) }
  let(:type_de_champ) { build(:type_de_champ_epci, procedure: procedure) }
  let(:champ) { Champs::EpciChamp.new }

  describe 'ancestors' do
    subject { described_class.new(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  describe '#all_possible_values' do
    let(:expected_values) do
      departements.map { |departement| "#{departement[:code]} (#{departement[:name]}) : https://geo.api.gouv.fr/epcis?codeDepartement=#{departement[:code]}" }
    end
    subject(:all_possible_values) { described_class.new(type_de_champ, procedure.active_revision).all_possible_values }

    it { expect(all_possible_values).to match(expected_values) }
  end

  describe '#example_value' do
    let(:departement_code) { departements.pick(:code) }
    let(:epci_code) { APIGeoService.epcis(departement_code).pick(:code) }
    subject(:example_value) { described_class.new(type_de_champ, procedure.active_revision).example_value }

    it { is_expected.to eq([departement_code, epci_code]) }
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    shared_examples "a transformation to" do |code_departement, value|
      it { is_expected.to match({ code_departement: code_departement, value: value }) }
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the value is empty' do
      let(:value) { '' }

      it { is_expected.to be_nil }
    end

    context 'when the value is a string' do
      let(:value) { 'hello' }

      it { is_expected.to be_nil }
    end

    context 'when the value is an array of one element' do
      let(:value) { ['01'] }

      it_behaves_like "a transformation to", '01', nil
    end

    context 'when the value is an array of two elements' do
      let(:value) { ['01', '200042935'] }

      it_behaves_like "a transformation to", '01', '200042935'
    end

    context 'when the value is a valid departement with a blank epci' do
      let(:value) { ['01', ''] }

      it_behaves_like "a transformation to", '01', nil
    end

    context 'when the value is an array of three or more elements' do
      let(:value) { ['01', '200042935', 'hello'] }

      it_behaves_like "a transformation to", '01', '200042935'
    end

    context 'when the departement code is unknown' do
      let(:value) { ['000'] }

      it { is_expected.to be_nil }
    end

    context 'when the epci code is unknown' do
      let(:value) { ['01', 'unknown'] }

      it { is_expected.to be_nil }
    end
  end

  private

  def departements
    APIGeoService.departements.sort_by { |departement| departement[:code] }
  end
end
