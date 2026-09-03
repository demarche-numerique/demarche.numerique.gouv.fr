# frozen_string_literal: true

describe ChampPresentations::CartePresentation do
  let(:cadastre_label) { "Parcelle n° 0042 - Feuille 000 AB - 1234 m² – Commune 75056" }
  let(:point_coordinates) { [2.428439, 46.538477] }
  let(:point_label) { "Un point situé à 46°32'19\"N 2°25'42\"E" }

  let(:cadastre_area) { instance_double(GeoArea, label: cadastre_label, point?: false) }
  let(:point_area) { instance_double(GeoArea, label: point_label, point?: true, geometry: { 'coordinates' => point_coordinates }) }

  let(:geo_areas) { [cadastre_area, point_area] }
  let(:presentation) { described_class.new(geo_areas) }

  describe '#to_s' do
    it 'formats labels, adding decimal coordinates for points' do
      expect(presentation.to_s).to eq(
        "#{cadastre_label}\n#{point_label} (#{point_coordinates[1]}, #{point_coordinates[0]})"
      )
    end
  end

  describe '#to_tiptap_node' do
    it 'returns a bullet list with formatted labels' do
      expected_labels = [cadastre_label, "#{point_label} (#{point_coordinates[1]}, #{point_coordinates[0]})"]

      expected = {
        type: 'bulletList',
        content: expected_labels.map do |label|
          {
            type: 'listItem',
            content: [
              {
                type: 'paragraph',
                content: [
                  { type: 'text', text: label },
                ],
              },
            ],
          }
        end,
      }

      expect(presentation.to_tiptap_node).to eq(expected)
    end
  end
end
