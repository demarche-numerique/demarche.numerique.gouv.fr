# frozen_string_literal: true

describe 'users/dossiers/brouillon', type: :view do
  let(:procedure) { create(:procedure, :with_type_de_champ, :with_notice, :with_service) }
  let(:dossier) { create(:dossier, state: Dossier.states.fetch(:brouillon), procedure: procedure) }
  let(:footer) { view.content_for(:footer) }
  let(:profile) { :user }

  before do
    sign_in dossier.user
    assign(:dossier, dossier)
    allow_any_instance_of(ActionView::Base).to receive(:administrateur_signed_in?).and_return(profile == :administrateur)
  end

  subject! { render }

  context "as an user" do
    it 'affiche le libellé de la démarche' do
      expect(rendered).to have_text(dossier.procedure.libelle)
    end

    it 'affiche un lien vers la notice' do
      expect(response).to have_css("a[href*='/rails/active_storage/blobs/']", text: "Télécharger le guide de la démarche")
      expect(rendered).not_to have_text("Ce lien est éphémère")
      expect(rendered).to have_text("TXT – 11 octets")
    end

    it 'affiche les boutons de validation' do
      expect(rendered).to have_selector('.dossier-edit-footer')
    end

    it 'prépare le footer' do
      expect(footer).to have_selector('footer')
    end

    context 'quand la démarche ne comporte pas de notice' do
      let(:procedure) { create(:procedure) }
      it { is_expected.not_to have_link("Télécharger le guide de la démarche") }
    end

    context 'when a dossier is for_tiers and the dossier en construction with email notification' do
      let(:dossier) { create(:dossier, :for_tiers_with_notification) }

      it 'displays the informations of the beneficiaire' do
        expect(rendered).to have_text("Identité du demandeur")
        expect(rendered).not_to have_text("Votre identité")
      end
    end
  end

  context "as an administrateur" do
    let(:profile) { :administrateur }

    before do
      create(:administrateur, user: dossier.user)
    end

    it 'affiche un avertissement à propos de la notice' do
      expect(rendered).to have_text("Ce lien est éphémère")
    end
  end
end
