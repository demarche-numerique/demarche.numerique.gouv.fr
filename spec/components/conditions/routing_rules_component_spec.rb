# frozen_string_literal: true

describe Conditions::RoutingRulesComponent, type: :component do
  include Logic

  describe '#sources in column mode' do
    let(:procedure) do
      create(:procedure, public_type_de_champs: [
        { type: :integer_number, libelle: 'age' },
        { type: :repetition, libelle: 'family', children: [{ type: :integer_number, libelle: 'child_age' }] },
      ])
    end
    let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
    let(:component) { Conditions::RoutingRulesComponent.new(groupe_instructeur:) }

    it 'excludes repetition tdcs from condition targets' do
      libelles = component.send(:sources_by_visibility)[:public].values.flatten(1).map(&:first)

      expect(libelles).to include('age')
      expect(libelles).not_to include('family')
    end

    context 'with a dossier link' do
      let(:target) { create(:procedure) }
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié', **tdc_options }]) }
      let(:libelles) { component.send(:sources_by_visibility)[:public].values.flatten(1).map(&:first) }
      let(:other_column_labels) { ['Dossier lié – N° dossier', 'Dossier lié – Date de dépôt du dossier', 'Dossier lié – Service porteur de la démarche'] }

      context 'limited to some procedures' do
        let(:tdc_options) { { procedures_limit: true, dossier_link_procedure_ids: [target.id] } }

        it { expect(libelles).not_to include('Dossier lié – Intitulé de la démarche', *other_column_labels) }
      end

      context 'not limited' do
        let(:tdc_options) { {} }

        it { expect(libelles).not_to include('Dossier lié – Intitulé de la démarche', *other_column_labels) }
      end
    end
  end

  describe 'render' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }, { type: :integer_number, libelle: 'Un champ nombre entier' }]) }
    let(:groupe_instructeur) { procedure.groupe_instructeurs.first }
    let(:drop_down_tdc) { procedure.draft_revision.type_de_champs.first }
    let(:integer_number_tdc) { procedure.draft_revision.type_de_champs.last }
    let(:routing_rule) { ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')) }
    let(:component) { described_class.new(groupe_instructeur: groupe_instructeur) }

    before do
      groupe_instructeur.update(routing_rule: routing_rule)
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
      context 'when routing rule can never be true' do
        let(:routing_rule) { ds_and([ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')), ds_eq(champ_value(drop_down_tdc.stable_id), constant('Paris'))]) }

        it 'explains why, without invalidating the rule used for routing' do
          expect(page).to have_text('Aucune valeur du champ « Votre ville » ne vérifie à la fois « est Lyon » et « est Paris »')
          expect(page).not_to have_text('règle invalide')
        end
      end

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
