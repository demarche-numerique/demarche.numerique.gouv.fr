# frozen_string_literal: true

RSpec.describe GroupeGestionnaire::GroupeGestionnaireListCommentaires::CommentaireComponent, type: :component do
  let_it_be(:gestionnaire) { create(:gestionnaire) }
  let_it_be(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
  let(:administrateur) { administrateurs.default }
  let(:sender) { administrateur }
  let(:commentaire_groupe) { groupe_gestionnaire }
  let!(:commentaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire: commentaire_groupe, sender:) }
  let(:component) { described_class.new(groupe_gestionnaire:, commentaire:) }

  subject { render_inline(component) }

  before { allow(component).to receive(:current_gestionnaire).and_return(gestionnaire) }

  context "when the commentaire is unread" do
    it do
      expect(subject).to have_text(administrateur.email)
      expect(subject).to have_css(".notifications .fr-sr-only", exact_text: "Messages non lus")
    end
  end

  context "when the commentaire has been seen" do
    before { gestionnaire.mark_commentaire_as_seen(groupe_gestionnaire, administrateur.id, "Administrateur") }

    it { expect(subject).not_to have_css(".notifications") }
  end

  context "when the current gestionnaire is the sender" do
    let(:sender) { gestionnaire }

    it { expect(subject).to have_text("Messages avec le groupe gestionnaire parent") }

    it "labels the thread in English" do
      I18n.with_locale(:en) { expect(subject).to have_text("Messages with the parent admins group") }
    end
  end

  context "when the commentaire comes from a child group" do
    let(:commentaire_groupe) { create(:groupe_gestionnaire, parent: groupe_gestionnaire, name: "Groupe enfant") }

    it { expect(subject).to have_text("#{administrateur.email} (Groupe enfant)") }
  end
end
