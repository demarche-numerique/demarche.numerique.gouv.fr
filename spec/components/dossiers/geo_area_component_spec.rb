# frozen_string_literal: true

RSpec.describe Dossiers::GeoAreaComponent, type: :component do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:geo_area) { create(:geo_area, :selection_utilisateur, :polygon, champ_data: champ) }

  before { render_inline(described_class.new(geo_area:, editing:)) }

  let(:feature_id) { geo_area.to_feature[:properties][:id] }

  context 'when editing' do
    let(:editing) { true }

    it 'links to the shape, edits its description and removes it in the editor' do
      link = page.find("react-component[name='Map/FeatureLink']", text: geo_area.label)
      expect(JSON.parse(link['props'])).to eq('id' => feature_id)
      input = page.find("react-component[name='Map/DescriptionInput']")
      expect(JSON.parse(input['props'])).to eq('id' => feature_id, 'label' => geo_area.label)
      button = page.find("react-component[name='Map/RemoveFeatureButton']")
      expect(JSON.parse(button['props'])).to eq('id' => feature_id, 'label' => geo_area.label)
    end
  end

  context 'when not editing' do
    let(:editing) { false }

    it "matches the id of the map's geojson feature so clicking it can zoom to the right shape" do
      link = page.find("react-component[name='Map/FeatureLink']", text: geo_area.label)
      expect(JSON.parse(link['props'])).to eq('id' => feature_id)
    end
  end
end
