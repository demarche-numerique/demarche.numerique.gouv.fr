# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20250820migrateOldFilterFormatTask do
    describe "#process" do
      let_it_be(:procedure) { procedures.individual }
      # instructeurs.admin, not .default: the latter is already assigned to
      # procedures.individual by the seeds, so a second assign_to would clash.
      let_it_be(:instructeur) { instructeurs.admin }
      let_it_be(:assign_to) { create(:assign_to, procedure: procedure, instructeur: instructeur) }
      let(:procedure_presentation) { create(:procedure_presentation, assign_to: assign_to) }

      subject(:process) { described_class.process(procedure_presentation) }

      context "when the filter is a string (old format)" do
        before do
          procedure_presentation.update!(
            suivis_filters: [
              FilteredColumn.new(column: procedure.find_column(label: 'Demandeur'), filter: 'plop'),
            ]
          )
        end

        it "normalizes the filter" do
          subject
          expect(procedure_presentation.reload.suivis_filters.first.filter).to eq({ operator: 'match', value: ['plop'] })
        end
      end

      context "when the filter is a hash (new format)" do
        before do
          procedure_presentation.update!(
            suivis_filters: [
              FilteredColumn.new(column: procedure.find_column(label: 'Demandeur'), filter: { operator: 'match', value: ['plop'] }),
            ]
          )
        end

        it "does not change the filter" do
          subject
          expect(procedure_presentation.reload.suivis_filters.first.filter).to eq({ operator: 'match', value: ['plop'] })
        end
      end

      context "when one filter is invalid" do
        let(:invalid_filtered_column) { FilteredColumn.new(column: double("Column", h_id: "{\"procedure_id\":8,\"column_id\":\"self/plop\"}"), filter: 'plop') }
        let(:valid_filtered_column) { FilteredColumn.new(column: procedure.find_column(label: 'Demandeur'), filter: 'plop') }

        before do
          procedure_presentation.update_columns(
            suivis_filters: [invalid_filtered_column],
            a_suivre_filters: [valid_filtered_column]
          )
        rescue ActiveRecord::RecordNotFound
        end

        it "does not crash" do
          expect { subject }.not_to raise_error
        end
      end
    end
  end
end
