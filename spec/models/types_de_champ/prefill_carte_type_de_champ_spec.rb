# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillCarteTypeDeChamp do
  let(:procedure) { build(:procedure) }
  let(:type_de_champ) { build(:type_de_champ_carte, procedure:) }
  let(:champ) { Champs::CarteChamp.new }
  let(:point) { build(:geo_area, :point).geometry.as_json }

  describe '#example_value' do
    subject(:example_value) { described_class.new(type_de_champ, procedure.active_revision).example_value }

    it { expect(JSON.parse(example_value)).to include('type' => 'Point') }
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    def a_geo_area_drawn(geometry)
      match(geo_areas: [have_attributes(source: 'selection_utilisateur', geometry:, properties: {})])
    end

    context 'when the value is a GeoJSON point as a JSON string' do
      let(:value) { point.to_json }

      it { is_expected.to a_geo_area_drawn(point) }
    end

    context 'when the value is a GeoJSON point as an object, with extra members' do
      let(:value) { point.merge('bbox' => [0, 0, 1, 1]) }

      it { is_expected.to a_geo_area_drawn(point) }
    end

    context 'when the value is a GeoJSON polygon' do
      let(:polygon) { build(:geo_area, :polygon).geometry.as_json }
      let(:value) { polygon.to_json }

      it { is_expected.to a_geo_area_drawn(polygon) }
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the value is not JSON' do
      let(:value) { 'hello' }

      it { is_expected.to be_nil }
    end

    context 'when the value is an array' do
      let(:value) { point['coordinates'] }

      it { is_expected.to be_nil }
    end

    context 'when the geometry type cannot be drawn on the map' do
      let(:value) { build(:geo_area, :multi_polygon).geometry.to_json }

      it { is_expected.to be_nil }
    end

    context 'when the coordinates are not numbers' do
      let(:value) { point.merge('coordinates' => point['coordinates'].map(&:to_s)) }

      it { is_expected.to be_nil }
    end

    context 'when the coordinates are out of WGS84 bounds' do
      let(:value) { build(:geo_area, :point_invalid).geometry.to_json }

      it { is_expected.to be_nil }
    end
  end
end
