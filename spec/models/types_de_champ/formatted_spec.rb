# frozen_string_literal: true

describe TypesDeChamp::Formatted do
  describe 'default options' do
    let(:type_de_champ) { create(:type_de_champ_formatted) }

    it 'are injected when loading a row whose options are empty' do
      TypeDeChamp.where(id: type_de_champ.id).update_all(options: {})

      reloaded = TypeDeChamp.find(type_de_champ.id)

      expect(reloaded.formatted_mode).to eq('simple')
      expect(reloaded.letters_accepted).to eq(true)
      expect(reloaded.numbers_accepted).to eq(true)
      expect(reloaded.special_characters_accepted).to eq(true)
    end

    it 'do not overwrite the persisted options' do
      type_de_champ.update!(formatted_mode: 'advanced', expression_reguliere: '\d+')

      reloaded = TypeDeChamp.find(type_de_champ.id)

      expect(reloaded.formatted_mode).to eq('advanced')
      expect(reloaded.expression_reguliere).to eq('\d+')
    end
  end
end
