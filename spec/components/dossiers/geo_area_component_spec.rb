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

    it "matches the id of the map's geojson feature so clicking it can zoom to the right shape" do
      expect(page.find("[data-controller='geo-area']")['data-geo-area-id-value']).to eq(feature_id)
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
