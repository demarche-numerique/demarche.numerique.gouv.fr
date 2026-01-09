# frozen_string_literal: true

describe 'wcag rules for usager', chrome: true do
  let(:procedure) { create(:procedure, :published, :with_service, :for_individual) }
  let(:password) { SECURE_PASSWORD }
  let(:litteraire_user) { create(:user, password: password) }

  def test_aria_label_do_not_mix_with_title_attribute
    elements = page.all("[aria-label][title]")
    elements.each do |element|
      expect(element[:title]).to be_blank, "path=#{path}, element title=\"#{element[:title]}\" mixes aria-label and title attributes"
    end
  end

  def test_expect_axe_clean_without_main_navigation
    # On page without main navigation content (like anonymous home page),
    # there are either a bug in axe, either dsfr markup is not conform to wcag2a.
    # There is no issue on pages having a child navigation.
    expect(page).to be_axe_clean.excluding("#modal-header__menu")
    expect(page).to be_axe_clean.within("#modal-header__menu").skipping("aria-prohibited-attr")
  end

  context 'pages without the need to be logged in' do
    before do
      visit path
    end

    context 'homepage' do
      let(:path) { root_path }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'sign_up page' do
      let(:path) { new_user_registration_path }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    scenario 'account confirmation page' do
      visit new_user_registration_path

      fill_in :user_email, with: "some@email.com"
      fill_in :user_password, with: "epeciusetuir"

      perform_enqueued_jobs do
        click_button 'Créer un compte'
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'sign_up confirmation' do
      let(:path) { user_confirmation_path("user[email]" => "some@email.com") }

      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
      end
    end

    context 'sign_in page' do
      let(:path) { new_user_session_path }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'password edit page' do
      let(:user) { create(:user, email: 'reset@pass.world', password: SECURE_PASSWORD, password_confirmation: SECURE_PASSWORD, reset_password_token: SecureRandom.hex) }
      let(:path) { edit_user_password_path(reset_password_token: user.reset_password_token) }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'password edit for experts' do
      let(:procedure) { create(:procedure, :published) }
      let(:avis) { create(:avis, dossier: create(:dossier, procedure: procedure), expert: nil, email: 'k@thx.bye') }
      let(:path) { sign_up_expert_avis_path(procedure_id: procedure.id, id: avis.id, email: avis.email) }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'contact page' do
      let(:path) { contact_path }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    context 'commencer page' do
      let(:path) { commencer_path(path: procedure.path) }
      it 'pass wcag tests' do
        test_aria_label_do_not_mix_with_title_attribute
        test_expect_axe_clean_without_main_navigation
      end
    end

    scenario 'commencer page, help dropdown' do
      visit commencer_path(path: procedure.reload.path)

      page.find(".fr-header__body .help-btn").click
      test_expect_axe_clean_without_main_navigation
    end
  end

  context "logged in, depot d’un dossier as individual" do
    before do
      login_as litteraire_user, scope: :user
      visit commencer_path(path: procedure.reload.path)
    end

    scenario 'écran identité usager' do
      click_on 'Commencer la démarche'
      expect(page).to be_axe_clean
    end

    # with no surprise, there's a lot of work on this one
    scenario "dépot d’un dossier" do
      click_on 'Commencer la démarche'

      within('.individual-infos') do
        fill_in('Prénom', with: 'prenom')
        fill_in('Nom', with: 'nom')
      end
      within "#identite-form" do
        click_on 'Continuer'
      end

      expect(page).to be_axe_clean
    end
  end

  context "logged in, depot d’un dossier entreprise" do
    let(:procedure) { create(:procedure, :with_service, :published) }

    before do
      login_as litteraire_user, scope: :user
      visit commencer_path(path: procedure.reload.path)
    end

    scenario "écran identification de l’entreprise" do
      click_on 'Commencer la démarche'
      expect(page).to be_axe_clean
    end
  end

  context "logged in, avec des dossiers déposés" do
    let(:dossier) { create(:dossier, procedure: procedure, user: litteraire_user) }
    before do
      login_as litteraire_user, scope: :user
    end

    scenario 'liste des dossiers sans dossiers' do
      visit dossiers_path
      expect(page).to be_axe_clean
    end

    scenario 'liste des dossiers avec des dossiers' do
      dossier
      visit dossiers_path
      expect(page).to be_axe_clean
      page.find("#actions_menu_dossier_#{dossier.id}_button").click
      expect(page).to be_axe_clean
    end

    scenario 'dossier' do
      visit dossier_path(dossier)
      expect(page).to be_axe_clean
    end

    scenario 'merci' do
      visit merci_dossier_path(dossier)
      expect(page).to be_axe_clean
    end

    scenario 'demande' do
      visit demande_dossier_path(dossier)
      expect(page).to be_axe_clean
    end

    scenario 'messagerie avec des messages' do
      create(:commentaire, dossier: dossier, instructeur: procedure.instructeurs.first, body: 'hello')
      create(:commentaire, dossier: dossier, email: dossier.user.email, body: 'hello')
      visit messagerie_dossier_path(dossier)
      expect(page).to be_axe_clean
    end

    scenario 'modifier' do
      visit modifier_dossier_path(dossier)
      expect(page).to be_axe_clean
    end

    scenario 'brouillon' do
      visit brouillon_dossier_path(dossier)
      expect(page).to be_axe_clean
    end
  end
end
