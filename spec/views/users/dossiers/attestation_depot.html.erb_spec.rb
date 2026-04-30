# frozen_string_literal: true

describe 'users/dossiers/attestation_depot', type: :view do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, libelle: 'Ma procédure de test', for_individual: true) }
  let(:dossier) { create(:dossier, :en_construction, user: user, procedure: procedure, for_individual?: true) }

  before do
    sign_in user
    dossier.individual.update!(nom: 'Dupont', prenom: 'Jean')
    assign(:dossier, dossier)
  end

  it 'affiche APPLICATION_NAME dans le bloc direction (droite)' do
    render
    expect(rendered).to have_css('.direction-site', text: APPLICATION_NAME)
  end

  it 'affiche le titre du reçu' do
    render
    expect(rendered).to have_css('.attestation-depot-title')
  end

  it 'affiche le libellé de la procédure' do
    render
    expect(rendered).to have_text('Ma procédure de test')
  end

  context "sans DIRECTION_LABEL (valeur par défaut vide)" do
    before do
      stub_const('DIRECTION_LABEL', '')
      render
    end

    it "n'affiche pas la ligne direction-label" do
      expect(rendered).not_to have_css('.direction-label')
    end
  end

  context "avec DIRECTION_LABEL renseigné" do
    before do
      stub_const('DIRECTION_LABEL', 'Direction Interministérielle du Numérique')
      render
    end

    it 'affiche DIRECTION_LABEL dans le bloc direction' do
      expect(rendered).to have_css('.direction-label', text: 'Direction Interministérielle du Numérique')
    end

    it 'affiche APPLICATION_NAME dans le bloc direction' do
      expect(rendered).to have_css('.direction-site', text: APPLICATION_NAME)
    end
  end

  context "avec LOGO_MARIANNE_SRC présent" do
    before { stub_const('LOGO_MARIANNE_SRC', 'Marianne-Light@2x.png') }

    it 'affiche le bloc Marianne' do
      render
      expect(rendered).to have_css('.bloc-marque')
    end
  end

  context "sans LOGO_MARIANNE_SRC (instance sans Marianne)" do
    before { stub_const('LOGO_MARIANNE_SRC', '') }

    it "n'affiche pas le bloc Marianne" do
      render
      expect(rendered).not_to have_css('.bloc-marque')
    end
  end
end
