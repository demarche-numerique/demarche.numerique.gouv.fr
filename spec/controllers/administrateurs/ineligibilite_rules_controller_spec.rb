# frozen_string_literal: true

describe Administrateurs::IneligibiliteRulesController, type: :controller do
  include Logic
  let(:user) { create(:user) }
  let(:admin) { create(:administrateur, user: create(:user)) }
  let(:procedure) { create(:procedure, administrateurs: [admin], public_type_de_champs:) }
  let(:public_type_de_champs) { [] }

  describe 'condition management' do
    before { sign_in(admin.user) }

    let(:default_params) do
      {
        procedure_id: procedure.id,
        revision_id: procedure.draft_revision.id,
      }
    end

    describe '#add_row' do
      subject { post :add_row, params: default_params, format: :turbo_stream }

      context 'without any row' do
        it 'creates an empty condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(nil)
            .to(empty_operator(empty, empty))
        end
      end

      context 'with row' do
        before do
          procedure.draft_revision.ineligibilite_rules = empty_operator(empty, empty)
          procedure.draft_revision.save!
        end

        it 'add one more creates an empty condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(empty_operator(empty, empty))
            .to(ds_and([
              empty_operator(empty, empty),
              empty_operator(empty, empty),
            ]))
        end
      end
    end

    describe 'delete_row' do
      let(:condition_form) do
        {
          top_operator_name: Logic::And.name,
          rows: [
            {
              targeted_champ: empty.to_json,
              operator_name:  Logic::EmptyOperator,
              value: empty.to_json,
            },
            {
              targeted_champ: empty.to_json,
              operator_name:  Logic::EmptyOperator,
              value: empty.to_json,
            },
          ],
        }
      end
      let(:initial_condition) do
        ds_and([
          empty_operator(empty, empty),
          empty_operator(empty, empty),
        ])
      end

      subject { delete :delete_row, params: default_params.merge(row_index: 0, procedure_revision: { condition_form: }), format: :turbo_stream }
      it 'remove condition' do
        procedure.draft_revision.update(ineligibilite_rules: initial_condition)

        expect { subject }
          .to change { procedure.draft_revision.reload.ineligibilite_rules }
          .from(initial_condition)
          .to(empty_operator(empty, empty))
      end
    end

    context 'simple tdc' do
      let(:public_type_de_champs) { [{ type: :yes_no }] }
      let(:yes_no_tdc) { procedure.draft_revision.public_flat_type_de_champs.first }
      let(:targeted_champ) { champ_value(yes_no_tdc.stable_id).to_json }

      describe '#change_targeted_champ' do
        let(:condition_form) do
          {
            rows: [
              {
                targeted_champ: targeted_champ,
                operator_name:  Logic::Eq.name,
                value: constant(true).to_json,
              },
            ],
          }
        end
        subject { patch :change_targeted_champ, params: default_params.merge(procedure_revision: { condition_form: }), format: :turbo_stream }
        it 'update condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(nil)
            .to(ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end
      end

      describe '#update' do
        let(:value) { constant(true).to_json }
        let(:operator_name) { Logic::Eq.name }
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
        subject { patch :update, params: default_params.merge(procedure_revision: { condition_form: condition_form }), format: :turbo_stream }
        it 'updates condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(nil)
            .to(ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end
      end
    end

    context 'repetition tdc' do
      let(:public_type_de_champs) { [{ type: :repetition, children: [{ type: :yes_no }] }] }
      let(:yes_no_tdc) { procedure.draft_revision.public_flat_type_de_champs.find { _1.type_champ == 'yes_no' } }
      let(:targeted_champ) { champ_value(yes_no_tdc.stable_id).to_json }
      let(:condition_form) do
        {
          rows: [
            {
              targeted_champ: targeted_champ,
              operator_name:  Logic::Eq.name,
              value: constant(true).to_json,
            },
          ],
        }
      end
      subject { patch :change_targeted_champ, params: default_params.merge(procedure_revision: { condition_form: }), format: :turbo_stream }
      describe "#update" do
        it 'update condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(nil)
            .to(ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end
      end

      describe '#change_targeted_champ' do
        let(:condition_form) do
          {
            rows: [
              {
                targeted_champ: targeted_champ,
                operator_name:  Logic::Eq.name,
                value: constant(true).to_json,
              },
            ],
          }
        end
        subject { patch :change_targeted_champ, params: default_params.merge(procedure_revision: { condition_form: }), format: :turbo_stream }
        it 'update condition' do
          expect { subject }.to change { procedure.draft_revision.reload.ineligibilite_rules }
            .from(nil)
            .to(ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { procedure_id: procedure.id } }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in but not admin of procedure' do
      before { sign_in(user) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed as admin' do
      before do
        sign_in(admin.user)
        subject
      end

      it { is_expected.to have_http_status(200) }

      context 'rendered without tdc' do
        let(:public_type_de_champs) { [] }
        render_views

        it { expect(response.body).to have_link("Ajouter un champ supportant les conditions d’inéligibilité") }
      end

      context 'rendered with tdc' do
        let(:public_type_de_champs) { [{ type: :yes_no }] }
        render_views

        it { expect(response.body).not_to have_link("Ajouter un champ supportant les conditions d’inéligibilité") }
      end
    end
  end

  describe 'change' do
    let(:params) do
      {
        procedure_id: procedure.id,
        procedure_revision: {
          ineligibilite_message: 'panpan',
          ineligibilite_enabled: '1',
        },
      }
    end
    before { sign_in(admin.user) }

    context 'when ineligibilite rules is empty' do
      it 'fails gracefull without ineligibilite rules' do
        patch :change, params: params
        draft_revision = procedure.reload.draft_revision
        expect(draft_revision.ineligibilite_enabled).to eq(false)
        expect(flash[:alert]).to include("Le champ « Les conditions d’inéligibilité » doit être rempli")
      end
    end

    context 'when ineligibilite rules is present' do
      let(:public_type_de_champs) { [{ type: :drop_down_list, stable_id: 1, options: ['opt'] }] }
      before do
        procedure.draft_revision.update(ineligibilite_rules: ds_eq(champ_value(1), constant('opt')))
      end

      it 'works' do
        patch :change, params: params
        draft_revision = procedure.reload.draft_revision
        expect(draft_revision.ineligibilite_message).to eq('panpan')
        expect(draft_revision.ineligibilite_enabled).to eq(true)
        expect(response).to redirect_to(admin_procedure_path(procedure))
        expect(flash.notice).not_to be_empty
      end
    end
  end
end
