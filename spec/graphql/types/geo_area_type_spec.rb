# frozen_string_literal: true

RSpec.describe Types::GeoAreaType do
  describe '.resolve_type' do
    subject { described_class.resolve_type(geo_area, {}) }

    context 'with a cadastre geo area' do
      let(:geo_area) { build(:geo_area, :cadastre, :polygon) }

      it { is_expected.to eq(Types::GeoAreas::ParcelleCadastraleType) }
    end

    context 'with a selection_utilisateur geo area' do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon) }

      it { is_expected.to eq(Types::GeoAreas::SelectionUtilisateurType) }
    end

    context 'with an rpg geo area' do
      let(:geo_area) { build(:geo_area, :polygon, source: GeoArea.sources.fetch(:rpg)) }

      it 'resolves to RpgType (regression for RAILS-K5X)' do
        is_expected.to eq(Types::GeoAreas::RpgType)
      end
    end
  end
end
