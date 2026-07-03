# frozen_string_literal: true

describe Champs::CheckboxChamp do
  let(:types_de_champ_public) { [{ type: :checkbox }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:boolean_champ) { dossier.project_champs_public.first.tap { _1.update_column(:value, value) } }
  let(:value) { '' }
  it_behaves_like "a boolean champ", false

  # TODO remove when normalize_checkbox_values is over
  describe '#true?' do
    subject { boolean_champ.true? }

    context "when the checkbox value is 'off'" do
      let(:value) { 'off' }

      it { is_expected.to eq(false) }
    end
  end
end
