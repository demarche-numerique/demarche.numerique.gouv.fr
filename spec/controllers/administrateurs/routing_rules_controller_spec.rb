# frozen_string_literal: true

describe Administrateurs::RoutingRulesController, type: :controller do
  include Logic
  include ActionView::RecordIdentifier

  before { sign_in(procedure.administrateurs.first.user) }

  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }, { type: :text, libelle: 'Un champ texte' }]) }
  let(:gi_2) { create(:groupe_instructeur, label: 'groupe 2', procedure: procedure) }
  let(:drop_down_tdc) { procedure.draft_revision.type_de_champs.first }
  let(:default_params) do
    {
      procedure_id: procedure.id,
      groupe_instructeur_id: gi_2.id,
    }
  end

  def replaced_block(key)
    target = dom_id(gi_2, key)
    Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[action='replace'][target='#{target}'] template ##{target}")
  end

  describe '#update' do
    let(:value) { empty.to_json }
    let(:targeted_champ) { champ_value(drop_down_tdc.stable_id).to_json }

    before { post :update, params: params, format: :turbo_stream }

    let(:params) { default_params.merge(groupe_instructeur: { condition_form: condition_form }) }

    let(:condition_form) do
      {
        rows: [
          {
            targeted_champ: targeted_champ,
            operator_name: operator_name,
            value: value,
          },
        ],
      }
    end

    context 'with Eq operator' do
      let(:operator_name) { Logic::Eq.name }
      it do
        expect(gi_2.reload.routing_rule).to eq(ds_eq(champ_value(drop_down_tdc.stable_id), empty))
      end

      context 'rendering' do
        render_views

        it do
          expect(replaced_block(:routing)).to be_present
          expect(replaced_block(:routing).at_css("##{dom_id(gi_2, :routing_rule)}")).to be_present
        end
      end

      context '#update value' do
        let(:value) { constant('Lyon').to_json }

        before { post :update, params: params, format: :turbo_stream }

        it do
          expect(gi_2.reload.routing_rule).to eq(ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
        end

        context 'targeted champ changed' do
          let(:last_tdc) { procedure.draft_revision.type_de_champs.last }
          let(:targeted_champ) { champ_value(last_tdc.stable_id).to_json }
          let(:value) { empty.to_json }

          before { post :update, params: params, format: :turbo_stream }

          it do
            expect(gi_2.reload.routing_rule).to eq(ds_eq(champ_value(last_tdc.stable_id), empty))
          end
        end
      end
    end

    context 'with NotEq operator' do
      let(:operator_name) { Logic::NotEq.name }
      it do
        expect(gi_2.reload.routing_rule).to eq(ds_not_eq(champ_value(drop_down_tdc.stable_id), empty))
      end

      context '#update value' do
        let(:value) { constant('Lyon').to_json }

        before { post :update, params: params, format: :turbo_stream }

        it do
          expect(gi_2.reload.routing_rule).to eq(ds_not_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
        end

        context 'targeted champ changed' do
          let(:last_tdc) { procedure.draft_revision.type_de_champs.last }
          let(:targeted_champ) { champ_value(last_tdc.stable_id).to_json }
          let(:value) { empty.to_json }

          before { post :update, params: params, format: :turbo_stream }

          it do
            expect(gi_2.reload.routing_rule).to eq(ds_not_eq(champ_value(last_tdc.stable_id), empty))
          end
        end
      end
    end
  end

  describe '#add_row' do
    render_views

    before do
      gi_2.update(routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), empty))
      post :add_row, params: default_params, format: :turbo_stream
    end

    it do
      expect(gi_2.reload.routing_rule).to eq(ds_and([ds_eq(champ_value(drop_down_tdc.stable_id), empty), empty_operator(empty, empty)]))
      expect(replaced_block(:routing_rule)).to be_present
    end
  end

  describe '#delete_row' do
    render_views

    before do
      gi_2.update(routing_rule: ds_and([ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')), empty_operator(empty, empty)]))
      post :delete_row, params: params.merge(row_index: 1), format: :turbo_stream
    end

    let(:params) { default_params.merge(groupe_instructeur: { condition_form: condition_form }) }

    let(:condition_form) do
      {
        rows: [
          {
            targeted_champ: champ_value(drop_down_tdc.stable_id).to_json,
            operator_name: Logic::Eq.name,
            value: constant('Lyon'),
          },
          {
            targeted_champ: empty,
            operator_name: Logic::Eq.name,
            value: empty,
          },
        ],
      }
    end

    it do
      expect(gi_2.reload.routing_rule).to eq(ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
      expect(replaced_block(:routing_rule)).to be_present
    end
  end

  describe '#change_targeted_champ' do
    render_views

    before { patch :change_targeted_champ, params: params, format: :turbo_stream }

    let(:params) { default_params.merge(groupe_instructeur: { condition_form: condition_form }, row_index: 0) }

    let(:condition_form) do
      {
        rows: [
          {
            targeted_champ: champ_value(drop_down_tdc.stable_id).to_json,
            operator_name: Logic::NotEq.name,
            value: empty.to_json,
          },
        ],
      }
    end

    it do
      expect(gi_2.reload.routing_rule).to eq(ds_eq(champ_value(drop_down_tdc.stable_id), constant('Paris')))
      expect(replaced_block(:routing_rule)).to be_present
    end
  end

  describe "#update_defaut_groupe_instructeur" do
    let(:procedure) { create(:procedure) }
    let(:gi_2) { create(:groupe_instructeur, label: 'groupe 2', procedure: procedure) }
    let(:params) do
      {
        procedure_id: procedure.id,
        defaut_groupe_instructeur_id: gi_2.id,
      }
    end

    before do
      post :update_defaut_groupe_instructeur, params: params, format: :turbo_stream
      procedure.reload
    end

    it { expect(procedure.defaut_groupe_instructeur.id).to eq(gi_2.id) }
  end
end
