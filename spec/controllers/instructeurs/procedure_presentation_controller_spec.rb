# frozen_string_literal: true

describe Instructeurs::ProcedurePresentationController, type: :controller do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }]) }
  let(:instructeur) { create(:instructeur) }
  let(:procedure_presentation) do
    groupe_instructeur = procedure.defaut_groupe_instructeur
    assign_to = create(:assign_to, instructeur:, groupe_instructeur:)
    assign_to.procedure_presentation_or_default_and_errors.first
  end
  describe '#update' do
    subject { patch :update, params: }
    let(:state_column) { procedure.dossier_state_column }

    let(:params) { { id: procedure_presentation.id }.merge(presentation_params) }

    context 'nominal case' do
      before { sign_in(instructeur.user) }

      let(:presentation_params) do
        {
          displayed_columns: [state_column.id],
          sorted_column: { order: 'asc', id: state_column.id },
          filters: [{ id: state_column.id, filter: 'en_construction' }],
          statut: 'tous',
        }
      end

      before do
        procedure_presentation.update!(tous_filters: [])
      end

      it 'updates the procedure_presentation' do
        expect(procedure_presentation.displayed_columns).to eq(procedure.default_displayed_columns)
        expect(procedure_presentation.sorted_column).to eq(procedure.default_sorted_column)
        expect(procedure_presentation.tous_filters).to eq([])

        subject
        expect(response).to redirect_to(instructeur_procedure_url(procedure))

        procedure_presentation.reload

        expect(procedure_presentation.displayed_columns).to eq([state_column])

        expect(procedure_presentation.sorted_column.column).to eq(state_column)
        expect(procedure_presentation.sorted_column.order).to eq('asc')

        filtered_column = FilteredColumn.new(column: state_column, filter: 'en_construction')
        expect(procedure_presentation.tous_filters).to eq([filtered_column])
        expect(procedure_presentation.customized).to eq(true)
      end
    end

    context 'with a wrong instructeur' do
      let(:another_instructeur) { create(:instructeur) }
      before { sign_in(another_instructeur.user) }

      let(:presentation_params) { { displayed_columns: [state_column.id] } }

      it 'does not update the procedure_presentation' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with an empty string in displayed_columns' do
      before { sign_in(instructeur.user) }

      let(:presentation_params) { { displayed_columns: [''] } }

      it 'removes the empty string' do
        subject
        expect(procedure_presentation.reload.displayed_columns).to eq([])
      end
    end

    context 'with an error in filters' do
      before { sign_in(instructeur.user) }

      let(:presentation_params) do
        { filters: [{ id: state_column.id, filter: '' }], statut: 'tous' }
      end

      it 'does not update the procedure_presentation' do
        subject

        expect(flash.alert).to include(/ne peut pas être vide/)
      end
    end

    context 'with an admin who set presentation as default for other instructeurs' do
      before { sign_in(instructeur.user) }

      let(:presentation_params) do
        {
          displayed_columns: [state_column.id],
          sorted_column: { order: 'asc', id: state_column.id },
          filters: [{ id: state_column.id, filter: 'en_construction' }],
          procedure_presentation: { admin_default_procedure_presentation_active_virtual: true },
          statut: 'tous',
        }
      end

      it 'updates the procedure_presentation and set as default' do
        expect(procedure_presentation.displayed_columns).to eq(procedure.default_displayed_columns)
        expect(procedure_presentation.procedure.admin_default_procedure_presentation_id).to eq(nil)
        expect(procedure_presentation.procedure.admin_default_procedure_presentation_active).to eq(false)

        subject
        expect(response).to redirect_to(instructeur_procedure_url(procedure))
        procedure_presentation.reload
        expect(procedure_presentation.displayed_columns).to eq([state_column])
        expect(procedure_presentation.procedure.admin_default_procedure_presentation_id).to eq(instructeur.procedure_presentation_for_procedure_id(procedure.id).id)
        expect(procedure_presentation.procedure.admin_default_procedure_presentation_active).to eq(true)
      end
    end
  end

  describe '#update_filter' do
    subject { patch :update_filter, params: }

    let(:column) { procedure.find_column(label: 'Votre ville') }

    let(:existing_filter) { FilteredColumn.new(column:, filter: { operator: 'in', value: ['Paris', 'Lyon'] }) }

    before do
      sign_in(instructeur.user)
      procedure_presentation.update!(tous_filters: [existing_filter])
    end

    context 'nominal case' do
      let(:params) { { id: procedure_presentation.id, statut: 'tous', filter_key: existing_filter.id, filter: { id: column.id, filter: { operator: 'in', value: ['Marseille'] } } } }
      it 'updates the filter' do
        subject

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<turbo-stream action="refresh">')

        expect(procedure_presentation.reload.tous_filters).to eq([FilteredColumn.new(column:, filter: { operator: 'in', value: ['Marseille'] })])
        expect(procedure_presentation.reload.customized).to eq(false)
      end
    end

    context 'when the value of filter is an empty string' do
      let(:params) { { id: procedure_presentation.id, statut: 'tous', filter_key: existing_filter.id, filter: { id: column.id, filter: { operator: 'in', value: [''] } } } }

      it 'rejects the empty string' do
        subject

        expect(procedure_presentation.reload.tous_filters).to eq([FilteredColumn.new(column:, filter: { operator: 'in', value: [] })])
      end
    end
  end

  describe '#persist_filters' do
    subject { post :persist_filters, params: }

    let(:state_column) { procedure.dossier_state_column }
    let(:dossier_id_column) { procedure.dossier_id_column }
    let(:notifications_column) { procedure.dossier_notifications_column }

    before { sign_in(instructeur.user) }

    context 'when apply_to_all_tabs is enabled' do
      let(:params) do
        {
          id: procedure_presentation.id,
          statut: 'tous',
          filters_columns: [state_column.id, dossier_id_column.id],
          apply_to_all_tabs: '1',
        }
      end

      before do
        # Set different filters for different statuses to verify they all get updated
        procedure_presentation.update!(
          a_suivre_filters: [FilteredColumn.new(column: notifications_column)],
          suivis_filters: [FilteredColumn.new(column: state_column, filter: { operator: 'match', value: ['en_construction'] })],
          traites_filters: [FilteredColumn.new(column: dossier_id_column)],
          tous_filters: []
        )
      end

      it 'replaces filters for all statuses with the same filters' do
        subject

        expect(response).to redirect_to(instructeur_procedure_path(procedure, statut: 'tous'))

        procedure_presentation.reload

        # All statuses should have the same filters (state_column and dossier_id_column)
        expect(procedure_presentation.a_suivre_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.suivis_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.traites_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.tous_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.supprimes_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.supprimes_recemment_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.expirant_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.archives_filters.map(&:column)).to eq([state_column, dossier_id_column])
      end
    end

    context 'when apply_to_all_tabs is disabled' do
      let(:params) do
        {
          id: procedure_presentation.id,
          statut: 'a-suivre',
          filters_columns: [state_column.id],
          apply_to_all_tabs: '0',
        }
      end

      before do
        procedure_presentation.update!(
          a_suivre_filters: [FilteredColumn.new(column: notifications_column)],
          suivis_filters: [FilteredColumn.new(column: dossier_id_column)]
        )
      end

      it 'only replaces filters for the specified statut' do
        subject

        expect(response).to redirect_to(instructeur_procedure_path(procedure, statut: 'a-suivre'))

        procedure_presentation.reload

        # Only a_suivre_filters should be updated
        expect(procedure_presentation.a_suivre_filters.map(&:column)).to eq([state_column])
        # Other statuses should remain unchanged
        expect(procedure_presentation.suivis_filters.map(&:column)).to eq([dossier_id_column])
      end
    end
  end

  describe '#clear_all_filters' do
    subject { post :clear_all_filters, params: }

    let(:state_column) { procedure.dossier_state_column }
    let(:dossier_id_column) { procedure.dossier_id_column }

    context 'nominal case' do
      before { sign_in(instructeur.user) }

      let(:params) do
        {
          id: procedure_presentation.id,
          statut: 'tous',
        }
      end

      before do
        # Set filters with values
        procedure_presentation.update!(
          tous_filters: [
            FilteredColumn.new(column: state_column, filter: { operator: 'match', value: ['en_construction'] }),
            FilteredColumn.new(column: dossier_id_column, filter: { operator: 'match', value: ['123'] }),
          ],
          a_suivre_filters: [
            FilteredColumn.new(column: state_column, filter: { operator: 'match', value: ['en_construction'] }),
          ]
        )
      end

      it 'clears filter values but keeps filter columns' do
        expect(procedure_presentation.tous_filters.first.filter).to eq({ operator: 'match', value: ['en_construction'] })
        expect(procedure_presentation.tous_filters.second.filter).to eq({ operator: 'match', value: ['123'] })
        expect(procedure_presentation.a_suivre_filters.first.filter).to eq({ operator: 'match', value: ['en_construction'] })

        subject

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<turbo-stream action="refresh">')

        procedure_presentation.reload

        # Columns should remain but filter values should be cleared for tous_filters
        expect(procedure_presentation.tous_filters.map(&:column)).to eq([state_column, dossier_id_column])
        expect(procedure_presentation.tous_filters.first.filter).to eq({ operator: 'match', value: [] })
        expect(procedure_presentation.tous_filters.second.filter).to eq({ operator: 'match', value: [] })

        # a_suivre_filters should remain with the same filter value
        expect(procedure_presentation.a_suivre_filters.first.filter).to eq({ operator: 'match', value: ["en_construction"] })
      end
    end
  end
end
