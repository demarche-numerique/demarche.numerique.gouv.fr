# frozen_string_literal: true

describe TypesDeChampEditor::InfoReferentielComponent, type: :component do
  describe 'render' do
    let(:component) { described_class.new(procedure:, type_de_champ:) }
    let(:types_de_champ_public) { [{ type: :referentiel }] }
    let(:type_de_champ) { procedure.draft_revision.root_types_de_champ_public.first.record }

    before do
      referentiel
      type_de_champ
      render_inline(component)
    end

    context "draft_procedure" do
      let(:procedure) { create(:procedure, types_de_champ_public:) }
      context 'having referentiel' do
        let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

        it "allows to edit referentiel" do
          expect(page).to have_link("Configurer le champ", href: Rails.application.routes.url_helpers.edit_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel.id))
        end
      end
      context 'not having referentiel' do
        let(:referentiel) { nil }

        it "new referentiel" do
          expect(page).to have_link("Configurer le champ", href: Rails.application.routes.url_helpers.new_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id))
        end
      end
    end

    context "published_procedure" do
      let(:procedure) { create(:procedure, :published, types_de_champ_public:) }

      context "having referentiel" do
        let(:referentiel) { create(:api_referentiel, :exact_match, types_de_champ: [type_de_champ]) }

        it "does not allow to edit existing referentiel" do
          expect(page).to have_link("Configurer le champ", href: Rails.application.routes.url_helpers.new_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id, referentiel_id: referentiel.id))
        end
      end

      context 'not having referentiel' do
        let(:referentiel) { nil }

        it "new referentiel" do
          expect(page).to have_link("Configurer le champ", href: Rails.application.routes.url_helpers.new_admin_procedure_referentiel_path(procedure, type_de_champ.stable_id))
        end
      end
    end
  end
end
