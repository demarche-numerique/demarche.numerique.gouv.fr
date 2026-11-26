# frozen_string_literal: true

describe TypesDeChamp::DateTypeDeChamp do
  describe '#champ_value_for_api' do
    let(:type_de_champ) { build(:type_de_champ_date) }
    let(:champ) { Champs::DateChamp.new(value: '2026-12-01') }

    # The GraphQL API is public: its values must not follow the display formats.
    it 'keeps its format in both locales' do
      expect(I18n.with_locale(:fr) { type_de_champ.champ_value_for_api(champ) }).to eq('01 décembre 2026')
      expect(I18n.with_locale(:en) { type_de_champ.champ_value_for_api(champ) }).to eq('01 December 2026')
    end
  end
end
