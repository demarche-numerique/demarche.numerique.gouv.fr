# frozen_string_literal: true

RSpec.describe Instructeurs::EditableFiltersComponent, type: :component do
  describe "render" do
    subject { render_inline(described_class.new(procedure_presentation:, instructeur_procedure:, statut:)) }

    let(:procedure) { create(:procedure) }
    let(:procedure_id) { procedure.id }
    let(:instructeur) { create(:instructeur) }
    let(:assign_to) { create(:assign_to, procedure: procedure, instructeur: instructeur) }
    let(:procedure_presentation) { create(:procedure_presentation, assign_to: assign_to) }
    let(:instructeur_procedure) { create(:instructeurs_procedure, instructeur: assign_to.instructeur, procedure: assign_to.procedure) }
    let(:statut) { 'suivis' }

    before do
      procedure_presentation.update!(
        suivis_filters: [
          FilteredColumn.new(column: procedure.dossier_state_column, filter: { operator: 'match', value: 'en_construction' }),
        ]
      )
    end

    it "renders the form for the filter" do
      subject
      expect(page).to have_text("État du dossier")

      react_component = page.find('react-component')
      react_props_items = JSON.parse(react_component['props'])

      expect(react_props_items["items"].map(&:first)).to eq([
        "En construction", "En instruction", "Accepté", "Refusé", "Classé sans suite",
      ])
      expect(react_props_items["value"]).to eq(["en_construction"])
    end
  end
end
