# frozen_string_literal: true

RSpec.describe GeoArea, type: :model do
  describe '#area' do
    let(:geo_area) { build(:geo_area, :polygon, champ_data: nil) }

    it { expect(geo_area.area).to eq(103.6) }
  end

  describe '#area (hourglass polygon)' do
    let(:geo_area) { build(:geo_area, :hourglass_polygon, champ_data: nil) }

    it { expect(geo_area.area).to eq(32.4) }
  end

  describe '#length' do
    let(:geo_area) { build(:geo_area, :line_string, champ_data: nil) }

    it { expect(geo_area.length).to eq(21.2) }
  end

  describe '#location' do
    let(:geo_area) { build(:geo_area, :point, champ_data: nil) }

    it { expect(geo_area.location).to eq("46°32'19\"N 2°25'42\"E") }

    context 'with out of range coordinates (RAILS-M8G)' do
      let(:geo_area) { build(:geo_area, :point_invalid, champ_data: nil) }

      it 'falls back to the raw coordinates instead of failing' do
        expect(geo_area.location).to eq('200, 100')
      end
    end
  end

  describe 'uuid' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:main_champ) { dossier.champ_data.first }
    let(:buffer_champ) do
      champ = main_champ.dup
      champ.stream = Dossier::USER_BUFFER_STREAM
      champ.save!(validate: false)
      champ
    end

    it 'is assigned on the main stream' do
      expect(create(:geo_area, :selection_utilisateur, :polygon, champ_data: main_champ).uuid).to be_present
    end

    it 'is assigned on a buffer stream too' do
      expect(create(:geo_area, :selection_utilisateur, :polygon, champ_data: buffer_champ).uuid).to be_present
    end

    it 'survives cloning to another stream' do
      geo_area = create(:geo_area, :selection_utilisateur, :polygon, champ_data: main_champ)
      clone = geo_area.dup.tap { it.champ_data = buffer_champ }.tap(&:save!)

      expect(clone.uuid).to eq(geo_area.uuid)
      expect(clone.to_feature[:properties][:id]).to eq(geo_area.to_feature[:properties][:id])
    end
  end

  describe 'validations' do
    context 'geometry' do
      subject! { geo_area.validate }

      context 'polygon' do
        let(:geo_area) { build(:geo_area, :polygon, champ_data: nil) }
        it { expect(geo_area.errors).not_to have_key(:geometry) }
      end

      context 'line_string' do
        let(:geo_area) { build(:geo_area, :line_string, champ_data: nil) }
        it { expect(geo_area.errors).not_to have_key(:geometry) }
      end

      context 'point' do
        let(:geo_area) { build(:geo_area, :point, champ_data: nil) }
        it { expect(geo_area.errors).not_to have_key(:geometry) }
      end

      context "allow empty {}" do
        let(:geo_area) { build(:geo_area, geometry: {}) }
        it { expect(geo_area.errors).not_to have_key(:geometry) }
      end

      context "nil" do
        let(:geo_area) { build(:geo_area, geometry: nil) }
        it do
          expect(geo_area.errors).to have_key(:geometry)
          expect(geo_area.errors[:geometry]).to include(I18n.t('activerecord.errors.models.geo_area.attributes.geometry.blank'))
        end
      end

      context 'invalid point' do
        let(:geo_area) { build(:geo_area, :invalid_point, champ_data: nil) }
        it do
          expect(geo_area.errors).to have_key(:geometry)
          expect(geo_area.errors[:geometry]).to include(I18n.t('activerecord.errors.models.geo_area.attributes.geometry.invalid_crs'))
        end
      end

      context 'invalid_right_hand_rule_polygon' do
        let(:geo_area) { build(:geo_area, :invalid_right_hand_rule_polygon, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'hourglass_polygon' do
        let(:geo_area) { build(:geo_area, :hourglass_polygon, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'point_invalid' do
        let(:geo_area) { build(:geo_area, :point_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'linestring_invalid' do
        let(:geo_area) { build(:geo_area, :linestring_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'multipoint_invalid' do
        let(:geo_area) { build(:geo_area, :multipoint_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'polygon_invalid' do
        let(:geo_area) { build(:geo_area, :polygon_invalid, champ_data: nil) }
        it do
          expect(geo_area.errors).to have_key(:geometry)
          expect(geo_area.errors[:geometry]).to include(I18n.t('activerecord.errors.models.geo_area.attributes.geometry.invalid_crs'))
        end
      end

      context 'multilinestring_invalid' do
        let(:geo_area) { build(:geo_area, :multilinestring_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'multipolygon_invalid' do
        let(:geo_area) { build(:geo_area, :multipolygon_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end

      context 'geometrycollection_invalid' do
        let(:geo_area) { build(:geo_area, :geometrycollection_invalid, champ_data: nil) }
        it { expect(geo_area.errors).to have_key(:geometry) }
      end
    end
  end

  describe "cadastre properties" do
    let(:geo_area) { build(:geo_area, :cadastre, champ_data: nil) }
    let(:legacy_geo_area) { build(:geo_area, :legacy_cadastre, champ_data: nil) }

    it "should be backward compatible" do
      expect("#{geo_area.code_dep}#{geo_area.code_com}").to eq(geo_area.commune)
      expect(geo_area.code_arr).to eq(geo_area.prefixe)
      expect(geo_area.surface_parcelle).to eq(geo_area.surface)
    end

    context "(legacy)" do
      it "should be forward compatible" do
        expect("#{legacy_geo_area.code_dep}#{legacy_geo_area.code_com}").to eq(legacy_geo_area.commune)
        expect(legacy_geo_area.code_arr).to eq(legacy_geo_area.prefixe)
        expect(legacy_geo_area.surface_parcelle).to eq(legacy_geo_area.surface)
        expect(legacy_geo_area.cid).to eq(geo_area.cid)
      end
    end
  end

  describe 'description' do
    context 'when properties is nil' do
      let(:geo_area) { build(:geo_area, properties: nil, champ_data: nil) }

      it { expect(geo_area.description).to be_nil }
    end
  end

  describe "#label" do
    context "when geo is a line" do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :line_string, champ_data: nil) }
      it "should return the label" do
        expect(geo_area.label).to eq("Une ligne longue de 21,2 m")
      end

      it "should return unknown length" do
        geo_area.geometry["coordinates"] = []
        expect(geo_area.label).to eq("Une ligne de longueur inconnue")
      end
    end

    context "when geo is a polygon" do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon, champ_data: nil) }
      it "should return the label" do
        expect(geo_area.label).to eq("Une aire de surface 103,6 m²")
      end

      it "should return unknown surface" do
        geo_area.geometry["coordinates"] = []
        expect(geo_area.label).to eq("Une aire de surface inconnue")
      end
    end

    context "when geo is a point" do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :point, champ_data: nil) }
      it "should return the label" do
        expect(geo_area.label).to eq("Un point situé à 46°32'19\"N 2°25'42\"E")
      end
    end

    context "when geo is a point with elevation" do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :point_with_z, champ_data: nil) }
      it "should return the label" do
        expect(geo_area.label).to eq("Un point situé à 46°32'19\"N 2°25'42\"E")
      end
    end

    context "when geo is a cadastre parcelle" do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :cadastre, champ_data: nil) }
      it "should return the label" do
        expect(geo_area.label).to eq("Parcelle n° 42 - Feuille 000 A11 - 123 m² – commune 75127")
      end

      context "when area is nil" do
        let(:geo_area) { build(:geo_area, :selection_utilisateur, :cadastre, properties: { "description" => "48°51'45.81\"N 2°17'15,33\"E" }, geometry: { "type" => "Point", "coordinates" => [7.754444, 48.610556] }, champ_data: nil) }

        before { allow(geo_area).to receive(:area).and_return(nil) }

        it "should not crash" do
          expect(geo_area.label).to eq("Parcelle n°  - Feuille   -  m² – commune ")
        end
      end
    end
  end

  # The map render is not triggered by geo_areas: it is triggered on dépôt and
  # on submissions of changes (cf. dossier_state_concern_spec).
  describe 'static map rendering' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :carte }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }

    it 'is not scheduled while the usager is drawing' do
      expect { create(:geo_area, :selection_utilisateur, :polygon, champ_data: champ) }
        .not_to have_enqueued_job(RenderCarteChampJob)
    end
  end
end
