# frozen_string_literal: true

RSpec.describe GroupeGestionnaire::GroupeGestionnaireListCommentaires::CommentaireComponent, type: :component do
  let(:component) { described_class.new(groupe_gestionnaire:, commentaire:) }
  let(:gestionnaire) { create(:gestionnaire) }
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [gestionnaire]) }
  let(:administrateur) { administrateurs.default }
  let(:commentaire) { create(:commentaire_groupe_gestionnaire, groupe_gestionnaire:, sender: administrateur) }

  subject { render_inline(component) }

  before { allow(component).to receive(:current_gestionnaire).and_return(gestionnaire) }

  context "when the commentaire is unread" do
    it do
      expect(subject).to have_text(administrateur.email)
      expect(subject).to have_css(".notifications .fr-sr-only", exact_text: "notification")
    end
  end

  context "when the commentaire has been seen" do
    before { gestionnaire.mark_commentaire_as_seen(groupe_gestionnaire, administrateur.id, "Administrateur") }

    it { expect(subject).not_to have_css(".notifications") }
  end
end
