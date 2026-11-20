# frozen_string_literal: true

describe DossierLinkHelper do
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, libelle: "Ma démarche", organisation: "Mon service", instructeurs: [instructeur]) }
  let(:dossier) { create(:dossier, :en_construction, procedure:) }

  describe "#dossier_linked_path" do
    context "when no access as a instructeur" do
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

  describe "#dossier_link_card?" do
    let(:nav_bar_profile) { :instructeur }
    let(:action_name) { "show" }

    before do
      allow(helper).to receive(:current_instructeur).and_return(instructeur)
      without_partial_double_verification do
        allow(helper.controller).to receive_messages(nav_bar_profile:, action_name:)
      end
    end

    it { expect(helper.dossier_link_card?(dossier)).to be(true) }

    context "when the page is not viewed as an instructeur" do
      let(:nav_bar_profile) { :user }

      it { expect(helper.dossier_link_card?(dossier)).to be(false) }
    end

    context "when the page is printed" do
      let(:action_name) { "print" }

      it { expect(helper.dossier_link_card?(dossier)).to be(false) }
    end

    context "when the linked dossier is a brouillon" do
      let(:dossier) { create(:dossier, :brouillon, procedure:) }

      it { expect(helper.dossier_link_card?(dossier)).to be(false) }
    end

    context "when the instructeur has no access to the linked dossier" do
      let(:dossier) { create(:dossier, :en_construction) }

      it { expect(helper.dossier_link_card?(dossier)).to be(false) }
    end
  end

  describe "#dossier_link_card_rows" do
    let(:rows) { helper.dossier_link_card_rows(dossier) }

    before { allow(helper).to receive(:current_instructeur).and_return(instructeur) }

    it "labels the rows with the dossier link column names" do
      expect(rows.map(&:first)).to eq(["N° dossier", "Date de dépôt du dossier", "Intitulé de la démarche", "Service porteur de la démarche"])
    end

    it "links the dossier number to the instructeur dossier page in a new tab" do
      link = Capybara.string(rows.first.second).find_link("Dossier n° #{dossier.id}", href: instructeur_dossier_path(procedure, dossier))
      expect(link[:target]).to eq("_blank")
      expect(link[:rel]).to eq("noopener")
      expect(link[:title]).to eq("Dossier n° #{dossier.id} — Nouvel onglet")
      expect(rows.first.third).to eq(copy: false)
    end

    it "translates the link to the dossier in English" do
      link = I18n.with_locale(:en) { Capybara.string(helper.dossier_link_card_rows(dossier).first.second).find_link("Application no. #{dossier.id}") }
      expect(link[:title]).to eq("Application no. #{dossier.id} — New tab")
    end

    it "fills the submission date, the procedure title and its agency" do
      expect(rows.drop(1).map(&:second)).to eq([dossier.depose_at.to_date.strftime("%d/%m/%Y"), "Ma démarche", "Mon service"])
    end
  end
end
