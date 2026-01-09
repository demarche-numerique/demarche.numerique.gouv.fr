# frozen_string_literal: true

describe Conditions::ConditionsErrorsComponent, type: :component do
  include Logic

  describe 'render' do
    let(:conditions) { [] }
    let(:source_tdcs) { [] }

    before { render_inline(described_class.new(conditions: conditions, source_tdcs: source_tdcs)) }

    context 'when there are no condition' do
      it { expect(page).to have_no_css('.errors-summary') }
    end

    context 'when the targeted_champ is not available' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:conditions) { [ds_eq(champ_value(tdc.stable_id), constant(1))] }

      it do
        expect(page).to have_css('.errors-summary')
        expect(page).to have_content("Un champ cible n’est plus disponible")
      end
    end

    context 'when the targeted_champ is unmanaged' do
      let(:tdc) { create(:type_de_champ_email) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_eq(champ_value(tdc.stable_id), constant(1))] }

      it do
        expect(page).to have_css('.errors-summary')
        expect(page).to have_content("Le champ « #{tdc.libelle} » est de type « adresse électronique » et ne peut pas être utilisé comme champ cible.")
      end
    end

    context 'when the types mismatch' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_eq(champ_value(tdc.stable_id), constant('a'))] }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » est de type « nombre entier ». Il ne peut pas être égal à « a ».") }
    end

    context 'when a number operator is applied on not a number' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [greater_than(champ_value(tdc.stable_id), constant('a text'))] }

      it { expect(page).to have_content("« Supérieur à » ne s’applique qu'à des nombres.") }
    end

    context 'when the include operator is applied on a list' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_include(champ_value(tdc.stable_id), constant('a text'))] }

      it { expect(page).to have_content("Lʼopérateur « inclus » ne s’applique qu’au choix simple ou multiple.") }
    end

    context 'when a choice is not in a drop_down' do
      let(:tdc) { create(:type_de_champ_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_eq(champ_value(tdc.stable_id), constant('another choice'))] }

      it { expect(page).to have_content("« another choice » ne fait pas partie de « #{tdc.libelle} ».") }
    end

    context 'when a choice is not in a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_include(champ_value(tdc.stable_id), constant('another choice'))] }

      it { expect(page).to have_content("« another choice » ne fait pas partie de « #{tdc.libelle} ».") }
    end

    context 'when an eq operator applies to a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_eq(champ_value(tdc.stable_id), constant(tdc.drop_down_options.first))] }

      it { expect(page).to have_content("« est » ne s’applique pas au choix multiple.") }
    end

    context 'when an not_eq operator applies to a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_not_eq(champ_value(tdc.stable_id), constant(tdc.drop_down_options.first))] }

      it { expect(page).to have_content("« n’est pas » ne s’applique pas au choix multiple.") }
    end

    context 'when target became unavailable but a right still references the value' do
      # Cf https://demarches-simplifiees.sentry.io/issues/3625488398/events/53164e105bc94d55a004d69f96d58fb2/?project=1429550
      # However maybe we should not have empty at left with still a constant at right
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:conditions) { [ds_eq(empty, constant('a text'))] }

      it { expect(page).to have_content("Un champ cible n’est plus disponible") }
    end
  end
end
