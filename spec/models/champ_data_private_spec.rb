# frozen_string_literal: true

describe ChampData do
  describe '#private?' do
    let(:type_de_champ) { build(:type_de_champ, :private) }
    let(:champ) { type_de_champ.build_champ }

    it do
      expect(champ.private?).to be_truthy
      expect(champ.public?).to be_falsey
    end
  end
end
