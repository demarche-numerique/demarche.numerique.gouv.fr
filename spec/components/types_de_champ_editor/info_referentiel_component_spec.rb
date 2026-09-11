# frozen_string_literal: true

describe TypesDeChampEditor::InfoReferentielComponent, type: :component do
  describe 'render' do
    let(:component) { described_class.new(procedure:, type_de_champ:) }
    let(:public_type_de_champs) { [{ type: :referentiel }] }
    let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }

    before do
      referentiel
      type_de_champ
      render_inline(component)
    end

    context "draft_procedure" do
      let(:procedure) { create(:procedure, public_type_de_champs:) }
      context 'having referentiel' do
        let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

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
      let(:procedure) { create(:procedure, :published, public_type_de_champs:) }

      context "having referentiel" do
        let(:referentiel) { create(:api_referentiel, :exact_match, type_de_champs: [type_de_champ]) }

        it "links to the referentiel, which the controller duplicates on write" do
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
  end
end
