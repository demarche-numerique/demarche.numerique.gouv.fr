# frozen_string_literal: true

describe GeojsonService do
  describe '.bbox' do
    subject { described_class.bbox(geojson) }

    let(:geojson) do
      {
        type: 'FeatureCollection',
        features: [
          { type: 'Feature', geometry: { type: 'Point', coordinates: [2.35, 48.85] } },
          { type: 'Feature', geometry: { type: 'LineString', coordinates: [[-1.55, 47.21], [5.37, 43.29]] } },
        ],
      }
    end

    it 'goes west, south, east, north, as GeoJSON requires' do
      is_expected.to eq([-1.55, 43.29, 5.37, 48.85])
    end
  end
end
