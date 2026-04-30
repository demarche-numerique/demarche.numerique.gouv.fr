# frozen_string_literal: true

module Maintenance
  RSpec.describe T20260303BackfillCustomizedOnProcedurePresentationsTask do
    describe "#process" do
      let(:procedure) { create(:procedure, :published) }
      let(:task) { described_class.new }

      let(:instructeur_1) { create(:instructeur) }
      let(:instructeur_2) { create(:instructeur) }

      let!(:assign_to_1) { create(:assign_to, procedure: procedure, instructeur: instructeur_1) }
      let!(:assign_to_2) { create(:assign_to, procedure: procedure, instructeur: instructeur_2) }

      let!(:presentation_default) do
        create(
          :procedure_presentation,
          assign_to: assign_to_1,
          displayed_columns: procedure.default_displayed_columns
        )
      end

      let!(:presentation_custom) do
        procedure_presentation = create(:procedure_presentation, assign_to: assign_to_2)

        custom_column = procedure.find_column(label: "Date de dépôt")

        procedure_presentation.update!(displayed_columns: [custom_column])
        procedure_presentation
      end

      it "sets customized to false when displayed columns match default" do
        task.process(presentation_default)

        expect(presentation_default.reload.customized).to eq(false)
      end

      it "sets customized to true when displayed columns differ from default" do
        task.process(presentation_custom)

        expect(presentation_custom.reload.customized).to eq(true)
      end

      it "ignores order of h_id when comparing" do
        column1 = instance_double("Column", h_id: "a")
        column2 = instance_double("Column", h_id: "b")

        allow(presentation_default)
          .to receive(:displayed_columns)
          .and_return([column2, column1])

        allow(procedure)
          .to receive(:default_displayed_columns)
          .and_return([column1, column2])

        task.process(presentation_default)

        expect(presentation_default.reload.customized).to eq(false)
      end
    end
  end
end
