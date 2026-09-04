# frozen_string_literal: true

describe ProcedurePresentation do
  include ActiveSupport::Testing::TimeHelpers

  let(:procedure) { create(:procedure, :published) }
  let(:procedure_id) { procedure.id }
  let(:instructeur) { create(:instructeur) }
  let(:assign_to) { create(:assign_to, procedure:, instructeur:) }

  describe 'validation' do
    it { expect(build(:procedure_presentation)).to be_valid }

    context 'of displayed columns' do
      it do
        pp = build(:procedure_presentation, displayed_columns: [{ table: "user", column: "reset_password_token", procedure_id: }])
        expect { pp.displayed_columns }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'of filters' do
      it 'validates the filter_column objects' do
        expect(build(:procedure_presentation, "suivis_filters": [{ id: { column_id: "user/email", procedure_id: }, "filter": "not so long filter value" }])).to be_valid
        expect(build(:procedure_presentation, "suivis_filters": [{ id: { column_id: "user/email", procedure_id: }, "filter": "exceedingly long filter value" * 400 }])).to be_invalid
      end
    end
  end

  describe 'destroy_filters_for!' do
    let(:procedure_presentation) do
      create(:procedure_presentation, assign_to:).tap do |pp|
        pp.update(a_suivre_filters: [FilteredColumn.new(column: procedure.find_column(label: 'Demandeur'), filter: 'mail')])
      end
    end

    subject { procedure_presentation.destroy_filters_for!('a-suivre') }

    it do
      expect { subject }
        .to change { procedure_presentation.a_suivre_filters.size }.from(1).to(0)
    end
  end

  describe '#update_filter_for_statut' do
    let(:procedure_presentation) { create(:procedure_presentation, assign_to:) }
    let(:column) { procedure.find_column(label: 'Demandeur') }
    let(:existing_filter) { FilteredColumn.new(column:, filter: { operator: "match", value: ['existing_filter_value'] }) }
    let(:updated_filter) { FilteredColumn.new(column:, filter: { operator: "match", value: ['updated_filter_value'] }) }
    let(:other_filter) { FilteredColumn.new(column:, filter: { operator: "match", value: ['other_filter_value'] }) }

    subject { procedure_presentation.update_filter_for_statut(statut, filter_key, updated_filter) }

    context 'when updating a filter' do
      let(:statut) { 'a-suivre' }
      let(:filter_key) { existing_filter.id }

      before do
        procedure_presentation.update(a_suivre_filters: [existing_filter, other_filter])
      end

      it 'updates only the specified filter' do
        expect { subject }
          .to change { procedure_presentation.a_suivre_filters }.from([existing_filter, other_filter]).to([updated_filter, other_filter])
      end
    end

    context 'when updating a filter that does not exist' do
      let(:statut) { 'traites' }
      let(:filter_key) { 'non_existent_filter_id' }

      before do
        procedure_presentation.update(traites_filters: [other_filter])
      end

      it 'does not change the filters' do
        expect { subject }
          .to not_change { procedure_presentation.traites_filters.map(&:as_json) }
      end
    end

    context 'when updating a filter in an empty statut' do
      let(:statut) { 'archives' }
      let(:filter_key) { 'any_filter_id' }

      before do
        procedure_presentation.update(archives_filters: [])
      end

      it 'does not change the filters' do
        expect { subject }
          .to not_change { procedure_presentation.archives_filters }
      end
    end
  end

  describe '#update_displayed_fields' do
    let(:en_construction_column) { procedure.find_column(label: 'Date de passage en construction') }
    let(:mise_a_jour_column) { procedure.find_column(label: 'Date du dernier évènement') }

    let(:procedure_presentation) do
      create(:procedure_presentation, assign_to:).tap do |pp|
        pp.update(sorted_column: SortedColumn.new(column: procedure.find_column(label: 'Demandeur'), order: 'desc'))
      end
    end

    subject do
      procedure_presentation.update(displayed_columns: [
        en_construction_column.id, mise_a_jour_column.id,
      ])
    end

    it 'should update displayed_fields' do
      expect(procedure_presentation.displayed_columns).to eq(procedure.default_displayed_columns)

      subject

      expect(procedure_presentation.displayed_columns).to eq([
        en_construction_column, mise_a_jour_column,
      ])
    end
  end

  describe '#unset_admin_default_on_procedure' do
    let(:procedure_presentation) { create(:procedure_presentation, assign_to:) }

    before do
      procedure.update!(admin_default_procedure_presentation_id: procedure_presentation.id, admin_default_procedure_presentation_active: true)
    end

    it 'unsets the admin default before the presentation is destroyed' do
      procedure_presentation.destroy!

      expect(procedure.reload.admin_default_procedure_presentation_id).to be_nil
      expect(procedure.admin_default_procedure_presentation_active).to be(false)
    end

    # Cron::DiscardedProceduresDeletionJob destroys presentations through the
    # groupe_instructeur cascade of a discarded procedure: the default scope
    # must not hide that procedure from the nullify, or the FK blocks the delete.
    context 'when the procedure is discarded' do
      before { procedure.discard! }

      it 'still unsets the admin default' do
        expect { procedure_presentation.destroy! }.not_to raise_error

        expect(Procedure.with_discarded.find(procedure.id).admin_default_procedure_presentation_id).to be_nil
      end
    end
  end
end
