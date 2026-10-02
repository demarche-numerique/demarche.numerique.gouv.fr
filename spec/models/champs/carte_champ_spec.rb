# frozen_string_literal: true

describe Champs::CarteChamp do
  let(:public_type_de_champs) { [{ type: :carte }] }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first.tap { _1.update(geo_areas:) } }
  let(:coordinates) { [[[2.3859214782714844, 48.87442541960633], [2.3850631713867183, 48.87273183590832], [2.3809432983398438, 48.87081237174292], [2.3859214782714844, 48.87442541960633]]] }
  let(:geo_json) do
    {
      "type" => 'Polygon',
      "coordinates" => coordinates,
    }
  end

  describe '#to_feature_collection' do
    subject { champ.to_feature_collection }

    let(:feature_collection) {
      {
        type: 'FeatureCollection',
        id: champ.stable_id,
        bbox: champ.bounding_box,
        features: features,
      }
    }

    context 'when has no geo_areas' do
      let(:geo_areas) { [] }
      let(:features) { [] }

      it { is_expected.to eq(feature_collection) }
    end

    context 'when has one geo_area' do
      let(:geo_areas) { [build(:geo_area, :selection_utilisateur, geometry: geo_json)] }
      let(:features) { geo_areas.map(&:to_feature) }

      it { is_expected.to eq(feature_collection) }
    end
  end

  describe "#for_export" do
    context "when geo areas is a point" do
      let(:geo_areas) { [build(:geo_area, :selection_utilisateur, :point)] }

      it "returns point label" do
        expect(champ.type_de_champ.champ_value_for_export(champ)).to eq("Un point situé à 46°32'19\"N 2°25'42\"E")
      end
    end

    context "when geo area is a cadastre parcelle" do
      let(:geo_areas) { [build(:geo_area, :selection_utilisateur, :cadastre)] }

      it "returns cadastre parcelle label" do
        expect(champ.type_de_champ.champ_value_for_export(champ)).to match(/Parcelle n° 42/)
      end
    end
  end

  describe '#value=' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte, options: { cadastres: '1' } }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first.tap { it.update!(geo_areas:) } }
    let(:selection) { build(:geo_area, :selection_utilisateur, :polygon, properties: { description: 'Un champ' }) }
    let(:parcelle) { build(:geo_area, :cadastre, :polygon, cadastre_state: :cadastre_fetched) }
    let(:geo_areas) { [selection, parcelle] }
    let(:point) { { 'type' => 'Point', 'coordinates' => [2.4, 46.5] } }
    let(:uuid) { SecureRandom.uuid }

    # What the editor sends: the features it was given, edited.
    let(:features) { champ.to_feature_collection[:features].map { it.deep_stringify_keys.merge('id' => it[:properties][:id]) } }

    def assign(features)
      champ.value = { type: 'FeatureCollection', features: }.to_json
    end

    it 'leaves the geo areas alone when the collection is sent back unchanged' do
      assign(features)

      expect(champ).not_to be_changed_for_autosave
    end

    it 'creates a geo area for a feature with an unknown id' do
      assign(features + [{ 'type' => 'Feature', 'id' => uuid, 'geometry' => point, 'properties' => { 'description' => 'Un puits', 'filename' => 'puits.gpx', 'area' => 12, 'numero' => '42' } }])
      champ.save!

      geo_area = champ.reload.geo_areas.find_by!(uuid:)
      expect(geo_area).to have_attributes(source: 'selection_utilisateur', geometry: point, properties: { 'description' => 'Un puits', 'filename' => 'puits.gpx' })
      expect(champ.value).to be_nil
    end

    it 'creates a parcelle with the properties of its tile and fetches its real geometry' do
      properties = { 'source' => 'cadastre', 'id' => uuid, 'cid' => '75127000B0042', 'numero' => '42', 'section' => 'B', 'prefixe' => '000', 'commune' => '75127', 'contenance' => 456, 'area' => 12 }
      assign(features + [{ 'type' => 'Feature', 'id' => uuid, 'geometry' => point, 'properties' => properties }])

      expect { champ.save! }.to have_enqueued_job(FetchCadastreRealGeometryJob)
      geo_area = champ.reload.geo_areas.find_by!(uuid:)
      expect(geo_area).to have_attributes(source: 'cadastre', cid: '75127000B0042')
      expect(geo_area.properties).to eq(properties.except('source', 'cid', 'area').merge('id' => '75127000B0042'))
    end

    it 'does not pick the same parcelle twice' do
      assign(features + [{ 'type' => 'Feature', 'id' => uuid, 'geometry' => point, 'properties' => { 'source' => 'cadastre', 'cid' => parcelle.cid } }])

      expect(champ.geo_areas.size).to eq(2)
    end

    it 'ignores a new feature whose id is not a uuid' do
      assign(features + [{ 'type' => 'Feature', 'id' => '1234', 'geometry' => point, 'properties' => {} }])

      expect(champ.geo_areas.size).to eq(2)
    end

    it 'updates the geometry and the description of a drawn shape' do
      features[0].merge!('geometry' => point, 'properties' => features[0]['properties'].merge('description' => 'Un autre champ'))
      assign(features)
      champ.save!

      expect(selection.reload).to have_attributes(geometry: point, description: 'Un autre champ')
    end

    it 'updates only the description of a parcelle, whose geometry comes from the cadastre' do
      features[1].merge!('geometry' => point, 'properties' => features[1]['properties'].merge('description' => 'Mon jardin'))
      assign(features)
      champ.save!

      expect(parcelle.reload.geometry).not_to eq(point)
      expect(parcelle.description).to eq('Mon jardin')
    end

    it 'destroys the geo areas missing from the collection' do
      assign([features[1]])
      champ.save!

      expect(champ.reload.geo_areas).to eq([parcelle])
    end

    it 'destroys every geo area for an empty collection' do
      assign([])
      champ.save!

      expect(champ.reload.geo_areas).to be_empty
    end

    context 'with invalid geometries' do
      let(:outside) { { 'type' => 'Point', 'coordinates' => [300, 100] } }

      it 'leaves them out, saves the rest and tells which ones' do
        features[1]['properties']['description'] = 'Mon jardin'
        assign([
          features[0].merge('geometry' => outside),
          features[1],
          { 'type' => 'Feature', 'id' => uuid, 'geometry' => outside, 'properties' => {} },
        ])
        champ.save!

        expect(champ.rejected_features.keys).to contain_exactly(selection.uuid, uuid)
        expect(champ.rejected_features[uuid]).to eq([I18n.t('activerecord.errors.models.geo_area.attributes.geometry.invalid_crs')])
        expect(selection.reload.geometry).not_to eq(outside)
        expect(parcelle.reload.description).to eq('Mon jardin')
        expect(champ.reload.geo_areas.size).to eq(2)
      end
    end

    it 'ignores a value that is not a feature collection' do
      [nil, '', 'not json', '[]', '{"features": {}}'].each { champ.value = it }

      expect(champ).not_to be_changed_for_autosave
    end

    context 'on the buffer stream of a dossier en construction' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }

      it 'keeps the feature ids of the main stream, which the editor was loaded with' do
        champ
        buffer_champ = dossier.with_update_stream(dossier.user) do
          dossier.public_champ_for_update(champ.public_id, updated_by: 'test')
        end

        buffer_champ.value = { type: 'FeatureCollection', features: [features[0]] }.to_json
        buffer_champ.save!

        expect(buffer_champ.reload.geo_areas.map(&:uuid)).to eq([selection.uuid])
        expect(champ.reload.geo_areas.size).to eq(2)
      end
    end
  end
end
