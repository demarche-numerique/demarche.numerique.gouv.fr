# frozen_string_literal: true

describe TypesDeChampEditor::ChampComponent, type: :component do
  describe 'render by type' do
    context 'explication' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :explication }]) }
      let(:tdc) { procedure.active_revision.root_types_de_champ_public.first }
      let(:coordinate) { procedure.draft_revision.coordinate_for(tdc) }
      let(:component) { described_class.new(coordinate: coordinate, upper_coordinates: []) }

      context 'not enabled' do
        before do
          allow(component).to receive(:current_user).and_return(procedure.administrateurs.first)
          render_inline(component)
        end

        it 'renders only collapsible_explanation_enabled checkbox' do
          expect(page).to have_selector('input[name="type_de_champ[collapsible_explanation_enabled]"]')
          expect(page).not_to have_selector('textarea[name="type_de_champ[collapsible_explanation_text]"]')
        end
      end

      context 'enabled' do
        before do
          tdc.record.update!(collapsible_explanation_enabled: "1")
          allow(component).to receive(:current_user).and_return(procedure.administrateurs.first)
          render_inline(component)
        end

        it 'renders both fields' do
          expect(page).to have_selector('input[name="type_de_champ[collapsible_explanation_enabled]"]')
          expect(page).to have_selector('textarea[name="type_de_champ[collapsible_explanation_text]"]')
        end
      end
    end
  end
end
