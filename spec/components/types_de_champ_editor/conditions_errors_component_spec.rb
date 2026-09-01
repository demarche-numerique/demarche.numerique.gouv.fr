# frozen_string_literal: true

describe Conditions::ConditionsErrorsComponent, type: :component do
  include Logic

  describe 'render' do
    let(:condition) { nil }
    let(:source_tdcs) { [] }

    before { render_inline(described_class.new(condition:, source_tdcs:)) }

    context 'when there are no condition' do
      it { expect(page).to have_no_css('.errors-summary') }
    end

    context 'when the targeted_champ is not available' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant(1)) }

      it do
        expect(page).to have_css('.errors-summary')
        expect(page).to have_content("Un champ cible n’est plus disponible")
      end
    end

    context 'when the targeted_champ is unmanaged' do
      let(:tdc) { create(:type_de_champ_email) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant(1)) }

      it do
        expect(page).to have_css('.errors-summary')
        expect(page).to have_content("Le champ « #{tdc.libelle} » est de type « adresse électronique » et ne peut pas être utilisé comme champ cible.")
      end
    end

    context 'when the types mismatch' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant('a')) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » est de type « nombre entier ». Il ne peut pas être égal à « a ».") }
    end

    context 'when a number operator is applied on not a number' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { greater_than(champ_value(tdc.stable_id), constant('a text')) }

      it { expect(page).to have_content("« Supérieur à » ne s’applique qu’à des nombres.") }
    end

    context 'when the include operator is applied on a list' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_include(champ_value(tdc.stable_id), constant('a text')) }

      it { expect(page).to have_content("Lʼopérateur « inclus » ne s’applique qu’au choix simple ou multiple.") }
    end

    context 'when a choice is not in a drop_down' do
      let(:tdc) { create(:type_de_champ_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant('another choice')) }

      it { expect(page).to have_content("« another choice » ne fait pas partie de « #{tdc.libelle} ».") }
    end

    context 'when a choice is not in a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_include(champ_value(tdc.stable_id), constant('another choice')) }

      it { expect(page).to have_content("« another choice » ne fait pas partie de « #{tdc.libelle} ».") }
    end

    context 'when an eq operator applies to a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant(tdc.drop_down_options.first)) }

      it { expect(page).to have_content("« est » ne s’applique pas au choix multiple.") }
    end

    context 'when an not_eq operator applies to a multiple_drop_down' do
      let(:tdc) { create(:type_de_champ_multiple_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_not_eq(champ_value(tdc.stable_id), constant(tdc.drop_down_options.first)) }

      it { expect(page).to have_content("« n’est pas » ne s’applique pas au choix multiple.") }
    end

    context 'when the rows are contradictory' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([greater_than(champ_value(tdc.stable_id), constant(3)), less_than(champ_value(tdc.stable_id), constant(2))]) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois supérieur à « 3 » et inférieur à « 2 ».") }
    end

    context 'when the rows are contradictory on a geographic champ' do
      let(:tdc) { create(:type_de_champ_departements) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([ds_in_region(champ_value(tdc.stable_id), constant('84')), ds_in_departement(champ_value(tdc.stable_id), constant('75'))]) }

      it 'names the region and the departement' do
        expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois est dans la région « Auvergne-Rhône-Alpes » et est dans le département « 75 – Paris ».")
      end
    end

    context 'when the rows are contradictory on a yes/no champ' do
      let(:tdc) { create(:type_de_champ_yes_no) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([ds_eq(champ_value(tdc.stable_id), constant(true)), ds_eq(champ_value(tdc.stable_id), constant(false))]) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois égal à « oui » et égal à « non ».") }
    end

    context 'when the rows are contradictory on the other option' do
      let(:tdc) { create(:type_de_champ_drop_down_list, drop_down_other: true) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([ds_eq(champ_value(tdc.stable_id), constant(Champs::DropDownListChamp::OTHER)), ds_eq(champ_value(tdc.stable_id), constant('val1'))]) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois égal à « Entrer une autre option » et égal à « val1 ».") }
    end

    context 'when the rows are contradictory on a region champ' do
      let(:tdc) { create(:type_de_champ_regions) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([ds_eq(champ_value(tdc.stable_id), constant('84')), ds_eq(champ_value(tdc.stable_id), constant('11'))]) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois égal à « Auvergne-Rhône-Alpes » et égal à « Île-de-France ».") }
    end

    context 'when the rows exclude every region a departement is in' do
      let(:tdc) { create(:type_de_champ_departements) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_and([ds_not_in_region(champ_value(tdc.stable_id), constant('84')), ds_not_in_departement(champ_value(tdc.stable_id), constant('75')), ds_in_departement(champ_value(tdc.stable_id), constant('01'))]) }

      it { expect(page).to have_content("ne peut pas être à la fois n’est pas dans la région « Auvergne-Rhône-Alpes », n’est pas dans le département « 75 – Paris » et est dans le département « 01 – Ain ».") }
    end

    context 'when the rows are contradictory on a column' do
      let(:tdc) { create(:type_de_champ_drop_down_list) }
      let(:source_tdcs) { [tdc] }
      let(:column) { champ_column_value(tdc.columns(procedure_id: nil).find { it.type == :enum }) }
      let(:condition) { ds_and([ds_eq(column, constant('val1')), ds_eq(column, constant('val2'))]) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut pas être à la fois égal à « val1 » et égal à « val2 ».") }
    end

    context 'when a single row can never be true' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(champ_value(tdc.stable_id), constant(2.5)) }

      it { expect(page).to have_content("Le champ « #{tdc.libelle} » ne peut jamais être égal à « 2.5 ».") }
    end

    context 'when the targeted champ is never displayed in that case' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:hidden_tdc) { create(:type_de_champ_yes_no, condition: greater_than(champ_value(tdc.stable_id), constant(10))) }
      let(:source_tdcs) { [tdc, hidden_tdc] }
      let(:condition) { ds_and([ds_eq(champ_value(hidden_tdc.stable_id), constant(true)), less_than(champ_value(tdc.stable_id), constant(5))]) }

      it { expect(page).to have_content("Cette condition ne peut jamais être vraie : le champ « #{hidden_tdc.libelle} » n’est pas affiché dans ce cas.") }
    end

    context 'when every targeted champ is hidden together' do
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:hidden_tdc) { create(:type_de_champ_yes_no, libelle: 'un', condition: greater_than(champ_value(tdc.stable_id), constant(10))) }
      let(:other_tdc) { create(:type_de_champ_yes_no, libelle: 'deux', condition: less_than(champ_value(tdc.stable_id), constant(5))) }
      let(:source_tdcs) { [tdc, hidden_tdc, other_tdc] }
      let(:condition) { ds_and([ds_eq(champ_value(hidden_tdc.stable_id), constant(true)), ds_eq(champ_value(other_tdc.stable_id), constant(true))]) }

      it 'lists every one of them' do
        expect(page).to have_content('le champ « un » n’est pas affiché dans ce cas.')
        expect(page).to have_content('le champ « deux » n’est pas affiché dans ce cas.')
      end
    end

    context 'with a placeholder row' do
      let(:condition) { ds_and([empty_operator(empty, empty)]) }

      it { expect(page).to have_no_css('.errors-summary') }
    end

    context 'when target became unavailable but a right still references the value' do
      # Cf https://demarches-simplifiees.sentry.io/issues/3625488398/events/53164e105bc94d55a004d69f96d58fb2/?project=1429550
      # However maybe we should not have empty at left with still a constant at right
      let(:tdc) { create(:type_de_champ_integer_number) }
      let(:source_tdcs) { [tdc] }
      let(:condition) { ds_eq(empty, constant('a text')) }

      it { expect(page).to have_content("Un champ cible n’est plus disponible") }
    end
  end
end
