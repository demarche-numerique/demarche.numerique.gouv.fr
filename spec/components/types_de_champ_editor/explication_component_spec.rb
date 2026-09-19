# frozen_string_literal: true

describe TypesDeChampEditor::ChampComponent, type: :component do
  describe 'render by type' do
    context 'explication' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :explication }]) }
      let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }
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
          coordinate.type_de_champ.update!(collapsible_explanation_enabled: "1")
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
