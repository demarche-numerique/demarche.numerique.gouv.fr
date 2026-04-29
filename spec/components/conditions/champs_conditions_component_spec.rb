# frozen_string_literal: true

describe Conditions::ChampsConditionsComponent, type: :component do
  include Logic

  let(:procedure) { create(:procedure) }

  describe 'render' do
    let(:tdc) { create(:type_de_champ, condition:) }
    let(:condition) { nil }
    let(:upper_tdcs) { [] }
    let(:component) { described_class.new(tdc:, upper_tdcs:, procedure:) }
    let(:column_mode) { false }

    before do
      allow(component).to receive(:feature_enabled?).with(:column_conditions).and_return(column_mode)
      render_inline(component)
    end

    context 'when there are no upper tdc' do
      it { expect(page).not_to have_text('Logique conditionnelle') }
    end

    context 'when there are upper tdcs but not managed' do
      let(:upper_tdcs) { [build(:type_de_champ_email)] }

      it { expect(page).not_to have_text('Logique conditionnelle') }
    end

    context 'when there are upper tdc but no condition to display' do
      let(:upper_tdcs) { [build(:type_de_champ_integer_number)] }

      it do
        expect(page).to have_text('Logique conditionnelle')
        expect(page).to have_button('cliquer pour activer')
        expect(page).not_to have_selector('table')
      end
    end

    context 'when there are upper tdc and a condition' do
      let(:upper_tdc) { create(:type_de_champ_number) }
      let(:upper_tdcs) { [upper_tdc] }

      shared_examples 'targeted condition rendering' do
        let(:upper_tdc_type) { :integer_number }

        context 'and one condition' do
          let(:condition) { ds_eq(target, constant(1)) }

          it do
            expect(page).to have_button('cliquer pour désactiver')
            expect(page).to have_selector('table')
            expect(page).to have_selector('tbody > tr', count: 1)
          end
        end

        context 'focus one row' do
          context 'enum' do
            let(:upper_tdc_type) { :drop_down_list }
            let(:condition) { empty_operator(target, constant(true)) }

            it do
              expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
              expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: ['Sélectionner', 'val1', 'val2', 'val3'])
            end
          end

          context 'regions' do
            let(:upper_tdc_type) { :regions }
            let(:condition) { empty_operator(target, constant(true)) }
            let(:region_options) { APIGeoService.regions.map { _1[:name] } }

            it do
              expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
              expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + region_options))
            end
          end
        end

        context 'when there are 3 conditions' do
          let(:condition) do
            ds_or([
              ds_eq(target, constant(1)),
              ds_eq(target, empty),
              greater_than(target, constant(3)),
            ])
          end

          it do
            expect(page).to have_selector('tbody > tr', count: 3)
            expect(page).to have_select("type_de_champ_condition_form_top_operator_name", selected: "Ou", options: ['Et', 'Ou'])
          end
        end
      end

      context 'in champ_value mode' do
        let(:upper_tdc) { create(:"type_de_champ_#{upper_tdc_type}") }
        let(:target) { champ_value(upper_tdc.stable_id) }

        include_examples 'targeted condition rendering'
      end

      context 'in column_value mode' do
        let(:column_mode) { true }
        # Le upper_tdc doit être attaché à la procedure pour que la
        # désérialisation de la condition (Column.find) retrouve la colonne.
        let(:procedure) do
          create(:procedure, types_de_champ_public: [{ type: upper_tdc_type, libelle: 'col' }])
        end
        let(:upper_tdc) { procedure.draft_revision.types_de_champ.first }
        let(:target) { column_value(upper_tdc.columns(procedure:).first) }

        include_examples 'targeted condition rendering'
      end

      context 'focus one row' do
        context 'empty' do
          let(:condition) { empty_operator(empty, empty) }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: ['Sélectionner'])
          end
        end

        context 'number' do
          let(:condition) { empty_operator(constant(1), constant(0)) }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Égal à'])
            expect(page).to have_selector('input[name="type_de_champ[condition_form][rows][][value]"][value=0]')
          end
        end

        context 'boolean' do
          let(:condition) { empty_operator(constant(true), constant(true)) }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est', 'N’est pas'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: ['Oui', 'Non'])
          end
        end

        context 'communes' do
          let(:communes) { create(:type_de_champ_communes) }
          let(:upper_tdcs) { [communes] }
          let(:condition) { empty_operator(champ_value(communes.stable_id), constant(true)) }
          let(:departement_options) { APIGeoService.departements.map { "#{_1[:code]} – #{_1[:name]}" } }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + departement_options))
          end
        end

        context 'epcis' do
          let(:epcis) { create(:type_de_champ_epci) }
          let(:upper_tdcs) { [epcis] }
          let(:condition) { empty_operator(champ_value(epcis.stable_id), constant(true)) }
          let(:departement_options) { APIGeoService.departements.map { "#{_1[:code]} – #{_1[:name]}" } }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + departement_options))
          end
        end

        context 'departements' do
          let(:departements) { create(:type_de_champ_departements) }
          let(:upper_tdcs) { [departements] }
          let(:condition) { empty_operator(champ_value(departements.stable_id), constant(true)) }
          let(:departement_options) { APIGeoService.departements.map { "#{_1[:code]} – #{_1[:name]}" } }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + departement_options))
          end
        end

        context 'pays' do
          let(:pays) { create(:type_de_champ_pays) }
          let(:upper_tdcs) { [pays] }
          let(:condition) { empty_operator(champ_value(pays.stable_id), constant(true)) }
          let(:pays_options) { APIGeoService.countries.map { "#{_1[:name]} – #{_1[:code]}" } }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + pays_options))
          end
        end

        context 'address' do
          let(:address) { create(:type_de_champ_address) }
          let(:upper_tdcs) { [address] }
          let(:condition) { empty_operator(champ_value(address.stable_id), constant(true)) }
          let(:departement_options) { APIGeoService.departements.map { "#{_1[:code]} – #{_1[:name]}" } }

          it do
            expect(page).to have_select('type_de_champ[condition_form][rows][][operator_name]', with_options: ['Est'])
            expect(page).to have_select('type_de_champ[condition_form][rows][][value]', options: (['Sélectionner'] + departement_options))
          end
        end
      end

      context 'and 2 conditions' do
        let(:condition) { ds_and([empty_operator(empty, empty), empty_operator(empty, empty)]) }

        it do
          expect(page).to have_selector('tbody > tr', count: 2)
          expect(page).to have_select("type_de_champ_condition_form_top_operator_name", selected: "Et", options: ['Et', 'Ou'])
        end
      end
    end
  end

  describe '.rows' do
    let(:tdc) { build(:type_de_champ, condition: condition) }
    let(:condition) { nil }

    subject { described_class.new(tdc: tdc, upper_tdcs: [], procedure: procedure).send(:rows) }

    context 'when there is one condition' do
      let(:condition) { ds_eq(empty, constant(1)) }

      it { is_expected.to eq([[empty, Logic::Eq.name, constant(1)]]) }
    end

    context 'when there are 2 conditions' do
      let(:condition) { ds_and([ds_eq(empty, constant(1)), ds_eq(empty, empty)]) }

      let(:expected) do
        [
          [empty, Logic::Eq.name, constant(1)],
          [empty, Logic::Eq.name, empty],
        ]
      end

      it { is_expected.to eq(expected) }
    end

    context 'when there are 3 conditions' do
      let(:upper_tdc) { create(:type_de_champ_number) }
      let(:upper_tdcs) { [upper_tdc] }

      let(:condition) do
        ds_or([
          ds_eq(champ_value(upper_tdc.stable_id), constant(1)),
          ds_eq(champ_value(upper_tdc.stable_id), empty),
          greater_than(champ_value(upper_tdc.stable_id), constant(3)),
        ])
      end

      let(:expected) do
        [
          [champ_value(upper_tdc.stable_id), Logic::Eq.name, constant(1)],
          [champ_value(upper_tdc.stable_id), Logic::Eq.name, empty],
          [champ_value(upper_tdc.stable_id), Logic::GreaterThan.name, constant(3)],
        ]
      end

      it { is_expected.to eq(expected) }
    end
  end
end
