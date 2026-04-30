# frozen_string_literal: true

RSpec.describe Referentiels::NewFormComponent, type: :component do
  describe 'render' do
    delegate :url_helpers, to: :routes
    delegate :routes, to: :application
    delegate :application, to: Rails

    let(:component) { described_class.new(referentiel:, type_de_champ:, procedure:) }
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) { [{ type: :referentiel }] }
    let(:type_de_champ) { procedure.draft_revision.types_de_champ_public.first }
    before do
      render_inline(component)
    end

    context 'when referentiel was not persisted' do
      let(:referentiel) { type_de_champ.build_referentiel }

      it 'render back button as destroy' do
        expect(page).to have_link("Annuler", href: url_helpers.champs_admin_procedure_path(procedure))
      end

      context 'when mode was not selected' do
        it 'renders form with hidden fields and no legacy inputs' do
          inputs = {
            referentiel_id: 1,
            hint: 1,
          }
          input[:type] = 2 if Referentiels::APIReferentiel.csv_available?

          expect(page).to have_css('form[method=post]')
          expect(page).to have_css("form[action=\"#{url_helpers.admin_procedure_referentiels_path(procedure, type_de_champ.stable_id)}\"]")
          expect(page).not_to have_selector('input[type="file"]')
          expect(page).not_to have_selector('input[name="referentiel[url]"]')
          expect(page).not_to have_selector('input[name="referentiel[test_data]"]')
          inputs.each do |input_name, count|
            expect(page).to have_selector("input[name=\"referentiel[#{input_name}]\"]", count:)
          end
          expect(page).to have_selector('input[type=submit][disabled]', count: 1)
        end
      end

      context 'with api was selected' do
        let(:referentiel) { type_de_champ.build_referentiel(type: "Referentiels::APIReferentiel") }
        it 'renders tiptap editor with url_tiptap input' do
          expect(page).to have_selector('.tiptap-editor')
          expect(page).to have_selector('input[name="referentiel[url_tiptap]"]')
          expect(page).not_to have_selector('input[name="referentiel[url]"]')
          expect(page).not_to have_selector('input[name="referentiel[test_data]"]')
          expect(page).to have_selector('input[type=submit][disabled]', count: 0)
        end
      end

      context 'with csv was selected' do
        let(:referentiel) { type_de_champ.build_referentiel(type: "Referentiels::CsvReferentiel") }
        it 'renders file input' do
          expect(page).to have_selector('input[type="file"]')
          expect(page).to have_selector('input[type=submit][disabled]', count: 0)
        end
      end
    end

    context 'when referentiel was persisted' do
      let(:referentiel) { create(:api_referentiel, :autocomplete, types_de_champ: [type_de_champ]) }
      it 'render form to update' do
        expect(page).to have_css('form[method=post]')
        expect(page).to have_css('input[name=_method][value=patch]')
        expect(page).to have_css("form[action=\"#{url_helpers.admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel)}\"]")
      end
    end
  end
end
