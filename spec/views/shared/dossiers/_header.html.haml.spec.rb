# frozen_string_literal: true

describe 'dossiers/show/header', type: :view do
  let(:procedure) { create(:procedure, :discarded) }
  let(:dossier) { create(:dossier, state: "brouillon", procedure: procedure) }
  let(:user) { dossier.user }

  before do
    sign_in user
  end

  subject! { render 'shared/dossiers/header', dossier: dossier }

  context "when the procedure is discarded with a dossier en brouillon" do
    it 'affiche que la démarche est supprimée' do
      expect(rendered).to have_text("La démarche liée à votre dossier est supprimée")
      expect(rendered).to have_text("Vous pouvez toujours consulter votre dossier, mais il ne sera pas traité par l’administration")
    end

    it 'cannot download the dossier' do
      expect(rendered).not_to have_text("Tout le dossier")
    end
  end

  context "when the procedure is closed with a dossier en brouillon" do
    let(:procedure) { create(:procedure, :closed) }

    it 'affiche que la démarche est close' do
      expect(rendered).to have_text("La démarche liée à votre dossier est close")
      expect(rendered).to have_text("Vous pouvez toujours consulter votre dossier, mais il ne sera pas traité par l’administration")
    end

    it 'cannot download the dossier' do
      expect(rendered).not_to have_text("Tout le dossier")
    end
  end

  context "when user is invited" do
    context "when the procedure is closed with a dossier en construction" do
      let(:procedure) { create(:procedure, :closed) }
      let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }
      let(:user) { create(:user) }

      before do
        create(:invite, user: user, dossier: dossier)
      end

      it "n’affiche pas de banner" do
        expect(rendered).not_to have_text("La démarche liée à votre dossier est close")
      end

      it 'can not download the dossier' do
        expect(rendered).not_to have_text("Tout le dossier")
      end
    end
  end

  describe "identity edit" do
    context "when the identity is individual" do
      let(:procedure) { create(:procedure, for_individual: true) }
      let(:dossier) { create(:dossier, :with_individual, state: "brouillon", procedure: procedure) }

      it "display identity with an edit link" do
        expect(rendered).to have_text(/Nom\s+#{dossier.individual.nom}/)
        expect(rendered).to have_link("Modifier l’identité")
      end
    end

    context "when the identity is an enterprise" do
      let(:procedure) { create(:procedure, for_individual: false) }
      let(:dossier) { create(:dossier, :with_entreprise, state: "brouillon", procedure: procedure) }

      it "display short identity with an edit siret link" do
        expect(rendered).to have_text(/Dénomination :\s+#{dossier.etablissement.entreprise_raison_sociale}/)
        expect(rendered).not_to have_text("Numéro de TVA")
        expect(rendered).to have_link("Modifier le SIRET")
      end
    end
  end
end
