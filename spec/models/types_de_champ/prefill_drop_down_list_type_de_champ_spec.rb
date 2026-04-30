# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillDropDownListTypeDeChamp do
  describe '#possible_values' do
    let(:procedure) { create(:procedure) }
    subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }

    before { type_de_champ.reload }

    context "when the drop down list accepts 'other'" do
      let(:type_de_champ) { build(:type_de_champ_drop_down_list, :with_other, procedure: procedure) }

      it {
        expect(possible_values).to match(
          ([I18n.t("views.prefill_descriptions.edit.possible_values.drop_down_list_other_html")] + type_de_champ.drop_down_options).to_sentence
        )
      }
    end

    context "when the drop down list does not accept 'other'" do
      let(:type_de_champ) { build(:type_de_champ_drop_down_list, procedure:) }

      it { expect(possible_values).to match(type_de_champ.drop_down_options.to_sentence) }
    end
  end

  describe '#possible_values does not contain unescaped HTML (XSS prevention)' do
    let(:procedure) { create(:procedure) }
    let(:xss_payload) { '<img src=x onerror=alert(1)>' }
    let(:type_de_champ) { build(:type_de_champ_drop_down_list, procedure: procedure, drop_down_options: ["safe_option", xss_payload]) }

    subject(:possible_values) { described_class.new(type_de_champ, procedure.active_revision).possible_values }

    it 'escapes HTML entities in drop_down_options' do
      expect(possible_values).not_to include('<img src=x')
    end
  end

  describe '#example_value' do
    let(:procedure) { create(:procedure) }
    let(:type_de_champ) { build(:type_de_champ_drop_down_list, procedure: procedure) }
    subject(:example_value) { described_class.new(type_de_champ, procedure.active_revision).example_value }

    it { expect(example_value).to eq(type_de_champ.drop_down_options.first) }
  end
end
