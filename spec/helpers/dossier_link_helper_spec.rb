# frozen_string_literal: true

describe DossierLinkHelper do
  describe "#dossier_linked_path" do
    context "when no access as a instructeur" do
      let(:instructeur) { create(:instructeur) }
      let(:dossier) { create(:dossier) }

      it { expect(helper.dossier_linked_path(instructeur, dossier)).to be_nil }
    end

    context "when no access as a user" do
      let(:user) { create(:user) }
      let(:dossier) { create(:dossier) }

      it { expect(helper.dossier_linked_path(user, dossier)).to be_nil }
    end

    context "when access as instructeur" do
      let(:procedure) { create(:procedure, :routee) }
      let(:dossier) { create(:dossier, groupe_instructeur: procedure.groupe_instructeurs.last) }
      let(:instructeur) { create(:instructeur) }

      before { procedure.groupe_instructeurs.last.instructeurs << instructeur }

      it { expect(helper.dossier_linked_path(instructeur, dossier)).to eq(instructeur_dossier_path(dossier.procedure, dossier)) }
    end

    context "when access as user" do
      let(:dossier) { create(:dossier) }
      let(:user) { create(:user) }

      before { dossier.user = user }

      it { expect(helper.dossier_linked_path(user, dossier)).to eq(dossier_path(dossier)) }
    end
  end

  describe "#dossier_link_summary" do
    let(:procedure) { create(:procedure, libelle: "Ma démarche", organisation: "Mon service") }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:summary) { Capybara.string(helper.dossier_link_summary(dossier, user)) }

    context "when the user owns the linked dossier" do
      let(:user) { dossier.user }

      it "renders the dossier number as a link opening in a new tab and emphasizes procedure and service" do
        expect(summary).to have_link("N° #{dossier.id}", href: dossier_path(dossier))
        expect(summary.find_link("N° #{dossier.id}")[:target]).to eq("_blank")
        expect(summary).to have_css("strong", text: "Ma démarche")
        expect(summary).to have_css("strong", text: "Mon service")
      end
    end

    context "when the user has no access to the linked dossier" do
      let(:user) { create(:user) }

      it "renders the dossier number as plain text without a link" do
        expect(summary).to have_no_link("N° #{dossier.id}")
        expect(summary).to have_text("N° #{dossier.id}")
      end
    end
  end
end
