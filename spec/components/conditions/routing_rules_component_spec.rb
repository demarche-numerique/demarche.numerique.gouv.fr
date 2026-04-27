# frozen_string_literal: true

describe Conditions::RoutingRulesComponent, type: :component do
  include Logic

  describe '#sources in column mode' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :integer_number, libelle: 'age' },
        { type: :repetition, libelle: 'family', children: [{ type: :integer_number, libelle: 'child_age' }] },
      ])
    end
    let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
    let(:component) { Conditions::RoutingRulesComponent.new(groupe_instructeur:) }

    before { allow(component).to receive(:feature_enabled?).with(:column_conditions).and_return(true) }

    it 'excludes repetition tdcs from condition targets' do
      libelles = component.send(:sources_by_section).values.flatten(1).map(&:first)

      expect(libelles).to include('age')
      expect(libelles).not_to include('family')
    end
  end

  describe 'render' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }, { type: :integer_number, libelle: 'Un champ nombre entier' }]) }
    let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
    let(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }
    let(:integer_number_tdc) { procedure.draft_revision.types_de_champ.last }
    let(:routing_rule) { ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')) }
    let(:component) { described_class.new(groupe_instructeur: groupe_instructeur) }

    before do
      groupe_instructeur.update(routing_rule: routing_rule)
      allow(component).to receive(:feature_enabled?).with(:column_conditions).and_return(false)
      render_inline(component)
    end

    context 'with one row' do
      context 'when routing rule is valid' do
        it do
          expect(page).to have_text('Champ Cible')
          expect(page).not_to have_text('règle invalide')
          expect(page).to have_select('groupe_instructeur[condition_form][rows][][operator_name]', options: ["Est", "N’est pas"])
        end
      end

      context 'when routing rule is invalid' do
        let(:routing_rule) { ds_eq(champ_value(drop_down_tdc.stable_id), empty) }
        it { expect(page).to have_text('règle invalide') }
      end
    end

    context 'with two rows' do
      context 'when routing rule is valid' do
        let(:routing_rule) { ds_and([ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')), ds_not_eq(champ_value(integer_number_tdc.stable_id), constant(33))]) }

        it do
          expect(page).not_to have_text('règle invalide')
          expect(page).to have_selector('tbody > tr', count: 2)
          expect(page).to have_select("groupe_instructeur_condition_form_top_operator_name", selected: "Et", options: ['Et', 'Ou'])
        end
      end

      context 'when routing rule is invalid' do
        let(:routing_rule) { ds_or([ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')), ds_not_eq(champ_value(integer_number_tdc.stable_id), empty)]) }
        it do
          expect(page).to have_text('règle invalide')
          expect(page).to have_selector('tbody > tr', count: 2)
          expect(page).to have_select("groupe_instructeur_condition_form_top_operator_name", selected: "Ou", options: ['Et', 'Ou'])
        end
      end
    end
  end
end
