# frozen_string_literal: true

describe 'user access to the list of their dossiers', js: true do
  let(:user) { create(:user) }
  let(:procedure_accuse_lecture)    { create(:procedure, :accuse_lecture) }
  let!(:dossier_brouillon)          { create(:dossier, user: user) }
  let!(:dossier_en_construction)    { create(:dossier, :with_populated_champs, :en_construction, user: user) }
  let!(:dossier_en_construction_2)  { create(:dossier, :en_construction, user: user) }
  let!(:dossier_en_instruction)     { create(:dossier, :en_instruction, user: user) }
  let!(:dossier_traite)             { create(:dossier, :accepte, user: user) }
  let!(:dossier_refuse)             { create(:dossier, :refuse, user: user) }
  let!(:dossier_a_corriger)         { create(:dossier_correction, dossier: dossier_en_construction_2) }
  let!(:dossier_archived)           { create(:dossier, :en_instruction, :archived, user: user) }
  let!(:dossier_for_tiers)          { create(:dossier, :en_instruction, :for_tiers_with_notification, user: user) }
  let!(:dossier_en_construction_with_accuse_lecture) { create(:dossier, :en_construction, user: user, procedure: procedure_accuse_lecture) }
  let!(:dossier_accepte_with_accuse_lecture) { create(:dossier, :accepte, user: user, procedure: procedure_accuse_lecture) }
  let!(:dossier_brouillon_expire) { create(:dossier, :with_individual, :with_populated_champs, :hidden_by_expired, user: user) }
  let!(:dossier_traite_expire) { create(:dossier, :accepte, :hidden_by_expired, user: user) }
  let!(:dossier_en_construction_supprime) { create(:dossier, :with_individual, :with_populated_champs, :en_construction, :hidden_by_user, user: user) }
  let(:dossiers_per_page) { 25 }
  let(:last_updated_dossier) { dossier_en_construction }

  before do
    @default_per_page = Dossier.default_per_page
    Dossier.paginates_per dossiers_per_page

    last_updated_dossier.update_column(:updated_at, Time.zone.parse("19/07/2052 15:35"))

    login_as user, scope: :user
    visit dossiers_path
  end

  after do
    Dossier.paginates_per @default_per_page
  end

  it 'the list of dossier is displayed' do
    expect(page).to have_content(dossier_brouillon.procedure.libelle)
    expect(page).to have_content(dossier_en_construction.procedure.libelle)
    expect(page).to have_content(dossier_en_instruction.procedure.libelle)
    expect(page).to have_content(dossier_archived.procedure.libelle)
    expect(page).to have_text('7 en cours')
    expect(page).to have_text('3 traités')
  end

  it 'the list must be ordered by last updated' do
    expect(page.body).to match(/#{last_updated_dossier.procedure.libelle}.*#{dossier_en_instruction.procedure.libelle}/m)
  end

  context 'when there are dossiers from other users' do
    let!(:dossier_other_user) { create(:dossier) }

    it 'doesn’t display dossiers belonging to other users' do
      expect(page).not_to have_content(dossier_other_user.procedure.libelle)
    end
  end

  context 'when there is more than one page' do
    let(:dossiers_per_page) { 2 }

    scenario 'the user can navigate through the other pages' do
      expect(page).not_to have_link(dossier_en_instruction.procedure.libelle)
      page.click_link("Suivant")
      page.click_link("Suivant")
      expect(page).to have_link(dossier_en_instruction.procedure.libelle)
      expect(page).to have_text('7 en cours')
      expect(page).to have_text('3 traités')
    end
  end

  context 'when the dossier is for_tiers' do
    let(:individual) { dossier_for_tiers.individual }

    it 'displays the name of the mandataire' do
      expect(page).to have_content("#{dossier_for_tiers.mandataire_full_name} (pour #{individual.prenom} #{individual.nom})")
    end
  end

  context 'when user uses filter' do
    scenario 'user filters state on tab "en-cours"' do
      expect(page).to have_text('7 en cours')
      expect(page).to have_text('3 traités')
      expect(page).to have_text('7 dossiers')

      click_on('Sélectionner un filtre')
      expect(page).to have_select 'Statut', selected: 'Sélectionner un statut', options: ['Sélectionner un statut', 'Brouillon', 'Déposé', 'En instruction', 'À corriger']
      select('Brouillon', from: 'Statut')
      click_on('Appliquer les filtres')

      expect(page).to have_text('1 dossier')
      expect(page).to have_select 'Statut', selected: 'Brouillon', options: ['Sélectionner un statut', 'Brouillon', 'Déposé', 'En instruction', 'À corriger']

      click_on('Sélectionner un filtre')
      select('À corriger', from: 'Statut')
      click_on('Appliquer les filtres')

      expect(page).to have_text('1 dossier')
      expect(page).to have_select 'Statut', selected: 'À corriger', options: ['Sélectionner un statut', 'Brouillon', 'Déposé', 'En instruction', 'À corriger']
    end

    scenario 'user filters state on tab "traité"' do
      visit dossiers_path(statut: 'traites')
      expect(page).to have_text('7 en cours')
      expect(page).to have_text('3 traités')
      expect(page).to have_text('3 dossiers')

      click_on('Sélectionner un filtre')
      expect(page).to have_select 'Statut', selected: 'Sélectionner un statut', options: ['Sélectionner un statut', 'Accepté', 'Refusé', 'Classé sans suite']
      select('Refusé', from: 'Statut')
      click_on('Appliquer les filtres')
      expect(page).to have_text('1 dossier')
      expect(page).to have_select 'Statut', selected: 'Refusé', options: ['Sélectionner un statut', 'Accepté', 'Refusé', 'Classé sans suite']

      click_on('Sélectionner un filtre')
      click_on('Réinitialiser')

      click_on('Sélectionner un filtre')
      expect(page).to have_select 'Statut', selected: 'Sélectionner un statut', options: ['Sélectionner un statut', 'Accepté', 'Refusé', 'Classé sans suite']
      select('Accepté', from: 'Statut')
      click_on('Appliquer les filtres')
      # we expect 1 dossier because we want do hide decision for dossier with accuse de lecture
      expect(page).to have_text('1 dossier')
      expect(page).to have_select 'Statut', selected: 'Accepté', options: ['Sélectionner un statut', 'Accepté', 'Refusé', 'Classé sans suite']

      click_on('Sélectionner un filtre')
      click_on('Réinitialiser')
      expect(page).to have_text('3 dossiers')
      expect(page).to have_select 'Statut', selected: 'Sélectionner un statut', options: ['Sélectionner un statut', 'Accepté', 'Refusé', 'Classé sans suite']
    end

    scenario 'user filters by created_at' do
      dossier_en_construction.update!(created_at: Date.yesterday)

      expect(page).to have_text('7 dossiers')
      click_on('Sélectionner un filtre')
      fill_in 'from_created_at_date', with: Date.today
      click_on('Appliquer les filtres')
      expect(page).to have_text('6 dossiers')
    end

    scenario 'user uses multiple filters' do
      dossier_en_construction.update!(created_at: Date.yesterday)

      expect(page).to have_select 'Statut', selected: 'Sélectionner un statut', options: ['Sélectionner un statut', 'Brouillon', 'Déposé', 'En instruction', 'À corriger']

      expect(page).to have_text('7 dossiers')
      click_on('Sélectionner un filtre')
      fill_in 'from_created_at_date', with: Date.today
      click_on('Appliquer les filtres')
      expect(page).to have_text('6 dossiers')
      expect(page).to have_text('1 filtre actif')

      click_on('Sélectionner un filtre')
      select('Déposé', from: 'Statut')
      click_on('Appliquer les filtres')
      expect(page).to have_text('2 dossiers')
      expect(page).to have_text('2 filtres actifs')

      click_on('Sélectionner un filtre')
      fill_in 'from_depose_at_date', with: Date.today
      click_on('Appliquer les filtres')
      expect(page).to have_text('2 dossiers')
      expect(page).to have_text('3 filtres actifs')
      click_on('3 filtres actifs')
      expect(page).to have_text('7 dossiers')
      expect(page).not_to have_text('5 filtres actifs')
    end
  end

  context 'when user clicks on a projet in list' do
    before do
      page.click_on(dossier_en_construction.procedure.libelle, match: :first)
    end

    scenario 'user is redirected to dossier page' do
      expect(page).to have_current_path(dossier_path(dossier_en_construction))
    end
  end

  describe 'deletion' do
    it 'should have links to delete dossiers' do
      expect(page).to have_link('Mettre à la corbeille', href: dossier_path(dossier_brouillon))
      expect(page).to have_link('Mettre à la corbeille', href: dossier_path(dossier_en_construction))
      expect(page).not_to have_link('Mettre à la corbeille', href: dossier_path(dossier_en_instruction))
    end

    context 'when user clicks on delete button' do
      scenario 'the dossier is deleted' do
        expect(page).to have_content(dossier_en_construction.procedure.libelle)
        within(:css, "#dossier_#{dossier_en_construction.id}", match: :first) do
          click_on 'Autres actions'
          accept_alert('Voulez-vous vraiment mettre à la corbeille ce dossier') do
            click_on 'Mettre à la corbeille'
          end
        end

        expect(page).to have_content('Votre dossier a bien été mis à la corbeille')
        expect(page).not_to have_content(dossier_en_construction.procedure.libelle)
      end
    end
  end

  describe 'active filter with no result' do
    before { create_list(:dossier, 10, :en_construction, user: user) }

    it 'renders the empty state without error' do
      visit dossiers_path(state: ['accepte'])
      expect(page).to have_content(/0 dossier|aucun dossier|Aucun résultat|Aucun dossier ne correspond/i)
    end
  end

  describe 'filter panel' do
    pending "TODO: JS interaction with DSFR modal, covered by controller spec for now"
  end

  describe 'clone' do
    it 'should have links to clone dossiers' do
      expect(page).to have_link(nil, href: clone_dossier_path(dossier_brouillon))
      expect(page).to have_link(nil, href: clone_dossier_path(dossier_en_construction))
      expect(page).to have_link(nil, href: clone_dossier_path(dossier_en_instruction))
    end

    context 'when user clicks on clone button' do
      scenario 'the dossier is cloned' do
        within(:css, ".card", match: :first) do
          click_on 'Autres actions'
          expect { click_on 'Dupliquer le dossier' }.to change { dossier_brouillon.user.dossiers.count }.by(1)
        end

        expect(page).to have_content("Votre dossier a bien été dupliqué. Vous pouvez maintenant le vérifier, l’adapter puis le déposer.")
      end
    end
  end

  describe 'restore' do
    it 'should have links to restore dossiers' do
      within('.fr-tabs__list') { click_on "corbeille" }
      expect(page).to have_link('Restaurer', href: restore_dossier_path(dossier_en_construction_supprime))
      expect(page).to have_button('Restaurer et étendre la conservation')
      expect(page).to have_link('Télécharger mon dossier', href: dossier_path("#{dossier_traite_expire.id}.pdf"))
    end

    context 'when user clicks on restore button' do
      scenario 'the dossier is restored' do
        within('.fr-tabs__list') { click_on "corbeille" }
        expect(page).to have_content(dossier_en_construction_supprime.procedure.libelle)
        click_on 'Restaurer le dossier'

        expect(page).to have_content('Votre dossier a bien été restauré')
      end
    end

    context 'when user clicks on restore and extend button' do
      scenario 'the dossier is restored and extended' do
        within('.fr-tabs__list') { click_on "corbeille" }
        expect(page).to have_content(dossier_brouillon_expire.procedure.libelle)
        click_on 'Restaurer et étendre la conservation'

        expect(page).to have_content('Votre dossier sera conservé 3 mois supplémentaire')
      end
    end

    context 'when user download PDF of expired' do
      scenario "generate PDF" do
        within('.fr-tabs__list') { click_on "corbeille" }
        click_on 'Télécharger mon dossier', match: :first
        # Test fails when an error happens during PDF generation
      end
    end
  end

  describe "user search bar" do
    context "when the dossier does not exist" do
      before do
        page.find_by_id('q').set(10000000)
        find('.fr-search-bar .fr-btn').click
      end

      it "shows an error message on the dossiers page" do
        expect(current_path).to eq(dossiers_path)
        expect(page).to have_content("Résultat de la recherche pour « 10000000 »")
        expect(page).to have_content("Aucun dossier")
        expect(page).to have_content("ne correspond aux termes recherchés")
      end
    end

    context "when the dossier does not belong to the user" do
      let!(:dossier_other_user) { create(:dossier) }

      before do
        page.find_by_id('q').set(dossier_other_user.id)
        find('.fr-search-bar .fr-btn').click
      end

      it "shows an error message on the dossiers page" do
        expect(current_path).to eq(dossiers_path)
        expect(page).to have_content("Résultat de la recherche pour « #{dossier_other_user.id} »")
        expect(page).to have_content("Aucun dossier")
        expect(page).to have_content("ne correspond aux termes recherchés")
        expect(page).to have_content("Réinitialiser la recherche")
      end
    end

    context "when the dossier belongs to the user" do
      before do
        page.find_by_id('q').set(dossier_en_construction.id)
        find('.fr-search-bar .fr-btn').click
      end

      it "appears in the result list" do
        expect(current_path).to eq(dossiers_path)
        expect(page).to have_content("Résultat de la recherche pour « #{dossier_en_construction.id} »")
        expect(page).not_to have_css('.fr-tabs')
        expect(page).to have_content(dossier_en_construction.id)
      end
    end

    context "when user search for something inside the dossier" do
      before do
        page.find_by_id('q').set(dossier_en_construction.project_champs_public.first.value)
      end

      context 'when it matches multiple dossiers' do
        let!(:dossier_with_champs) { create(:dossier, :with_populated_champs, :en_construction, user: user) }
        before do
          perform_enqueued_jobs(only: DossierIndexSearchTermsJob)
          find('.fr-search-bar .fr-btn').click
        end

        it "appears in the result list" do
          expect(current_path).to eq(dossiers_path)
          expect(page).to have_link(dossier_en_construction.procedure.libelle)
          expect(page).to have_link(dossier_with_champs.procedure.libelle)
          expect(page).to have_text("2 dossiers")
        end

        it "can be filtered by procedure and display the result - one item" do
          select dossier_en_construction.procedure.libelle, from: 'procedure_id'
          click_on 'Afficher'
          expect(page).to have_link(dossier_en_construction.procedure.libelle)
          expect(page).not_to have_link(dossier_with_champs.procedure.libelle)
          expect(page).to have_text("1 dossier")
        end

        it "can be filtered by procedure and display the result - no item" do
          select dossier_brouillon.procedure.libelle, from: 'procedure_id'
          click_on 'Afficher'
          expect(page).not_to have_link(String(dossier_en_construction.id))
          expect(page).not_to have_link(String(dossier_with_champs.id))
          expect(page).to have_content("Résultat de la recherche pour « #{dossier_en_construction.project_champs_public.first.value} » et pour la procédure « #{dossier_brouillon.procedure.libelle} » ")
          expect(page).to have_text("Aucun dossier")
        end
      end
    end
  end

  describe "filter by procedure" do
    context "when dossiers are on different procedures" do
      it "can filter by procedure" do
        expect(page).to have_text('7 en cours')
        expect(page).to have_text('3 traités')
        expect(page).to have_select('procedure_id', selected: 'Sélectionnez une démarche')
        select dossier_brouillon.procedure.libelle, from: 'procedure_id'
        click_on 'Afficher'
        expect(page).to have_text('1 en cours')
      end
    end
  end
end
