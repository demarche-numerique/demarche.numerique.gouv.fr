# frozen_string_literal: true

describe Administrateurs::ConditionsController, type: :controller do
  include Logic

  before { sign_in(procedure.administrateurs.first.user) }

  context 'without bloc repetition' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :integer_number }] * 3) }
    let(:first_tdc) { procedure.draft_revision.types_de_champ.first }
    let(:second_tdc) { procedure.draft_revision.types_de_champ.second }
    let(:third_tdc) { procedure.draft_revision.types_de_champ.third }

    before { sign_in(procedure.administrateurs.first.user) }

    let(:default_params) do
      {
        procedure_id: procedure.id,
        stable_id: third_tdc.stable_id,
      }
    end

    describe '#update' do
      render_views

      before { post :update, params: params, format: :turbo_stream }

      let(:params) { default_params.merge(type_de_champ: { condition_form: condition_form }) }

      let(:condition_form) do
        {
          rows: [
            {
              targeted_champ: champ_value(first_tdc.stable_id).to_json,
              operator_name: Logic::Eq.name,
              value: '2',
            },
          ],
        }
      end

      it do
        expect(third_tdc.reload.condition).to eq(ds_eq(champ_value(first_tdc.stable_id), constant(2)))
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(third_tdc))
        expect(assigns(:upper_tdcs)).to eq([first_tdc, second_tdc])
        expect(response.body).to include('<turbo-stream action="replace" target="autosave-notice">')
      end

      context 'when procedure is published' do
        render_views

        let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :integer_number }] * 3) }

        it 'renders the unpublished changes banner' do
          expect(response.body).to include('sticky-header-warning')
        end
      end
    end

    describe '#add_row' do
      before { post :add_row, params: default_params, format: :turbo_stream }

      it do
        expect(third_tdc.reload.condition).to eq(empty_operator(empty, empty))
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(third_tdc))
        expect(assigns(:upper_tdcs)).to eq([first_tdc, second_tdc])
      end
    end

    describe '#delete_row' do
      before { delete :delete_row, params: params.merge(row_index: 0), format: :turbo_stream }

      let(:params) { default_params.merge(type_de_champ: { condition_form: condition_form }) }

      let(:condition_form) do
        {
          rows: [
            {
              targeted_champ: champ_value(1).to_json,
              operator_name: Logic::Eq.name,
              value: '2',
            },
          ],
        }
      end

      it do
        expect(third_tdc.reload.condition).to eq(nil)
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(third_tdc))
        expect(assigns(:upper_tdcs)).to eq([first_tdc, second_tdc])
      end
    end

    describe '#destroy' do
      before do
        second_tdc.update(condition: empty_operator(empty, empty))
        delete :destroy, params: default_params, format: :turbo_stream
      end

      it do
        expect(third_tdc.reload.condition).to eq(nil)
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(third_tdc))
        expect(assigns(:upper_tdcs)).to eq([first_tdc, second_tdc])
      end
    end

    describe '#change_targeted_champ' do
      before do
        second_tdc.update(condition: empty_operator(empty, empty))
        patch :change_targeted_champ, params: params, format: :turbo_stream
      end

      let(:params) { default_params.merge(type_de_champ: { condition_form: condition_form }) }

      let(:condition_form) do
        {
          rows: [
            {
              targeted_champ: champ_value(second_tdc.stable_id).to_json,
              operator_name: Logic::EmptyOperator.name,
              value: empty.to_json,
            },
          ],
        }
      end

      it do
        expect(third_tdc.reload.condition).to eq(ds_eq(champ_value(second_tdc.stable_id), constant(0)))
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(third_tdc))
        expect(assigns(:upper_tdcs)).to eq([first_tdc, second_tdc])
      end
    end

    describe '#change_targeted_champ on a draft-only referentiel column' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: []) }
      let(:draft) { procedure.draft_revision }

      let!(:dropdown_tdc) { draft.add_type_de_champ(type_champ: 'integer_number') }
      let!(:text_tdc) { draft.add_type_de_champ(type_champ: 'text', after_stable_id: dropdown_tdc.stable_id) }

      let(:int_column) { dropdown_tdc.columns(procedure:).first }

      before do
        Flipper.enable(:column_conditions)
        sign_in(procedure.administrateurs.first.user)
        patch :change_targeted_champ,
          params: {
            procedure_id: procedure.id,
            stable_id: text_tdc.stable_id,
            row_index: 0,
            type_de_champ: {
              condition_form: {
                rows: [
                  {
                    targeted_champ: column_value(int_column).to_json,
                                    operator_name: Logic::EmptyOperator.name,
                                    value: empty.to_json,
                  },
                ],
              },
            },
          },
          format: :turbo_stream
      end

      it 'binds the column from the draft revision so the rendered component sees a typed left operand' do
        draft_tdcs = procedure.draft_revision.types_de_champ
        condition = assigns(:tdc).condition
        expect(condition).to be_a(Logic::Eq)
        expect(condition.left).to be_a(Logic::ColumnValue)
        expect(condition.left.type(draft_tdcs)).to eq(:number)
      end
    end
  end

  context 'with a repetiton bloc' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :integer_number, libelle: 'top_1' },
        {
          type: :repetition,
          libelle: 'repetition',
          children: [
            { type: :integer_number, libelle: 'child_1' },
            { type: :integer_number, libelle: 'child_2' },
          ],
        },
      ])
    end
    let(:tdcs) { procedure.draft_revision.types_de_champ }
    let(:top) { tdcs.find { _1.libelle == 'top_1' } }
    let(:repetition) { tdcs.find { _1.libelle == 'repetition' } }
    let(:child_1) { tdcs.find { _1.libelle == 'child_1' } }
    let(:child_2) { tdcs.find { _1.libelle == 'child_2' } }

    let(:default_params) do
      {
        procedure_id: procedure.id,
        stable_id: child_2.stable_id,
      }
    end

    describe '#add_row' do
      before do
        post :add_row, params: default_params, format: :turbo_stream
      end

      it do
        expect(child_2.reload.condition).to eq(empty_operator(empty, empty))
        expect(assigns(:coordinate)).to eq(procedure.draft_revision.coordinate_for(child_2))
        expect(assigns(:upper_tdcs)).to eq([child_1, top])
      end
    end
  end
end
