# frozen_string_literal: true

describe Champs::YesNoChamp do
  it_behaves_like "a boolean champ", true do
    let(:boolean_champ) { build_projected_champ(build(:type_de_champ_yes_no), value:) }
  end
end
