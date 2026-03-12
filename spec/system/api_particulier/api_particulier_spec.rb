# frozen_string_literal: true

describe 'fetch API Particulier Data', js: true do
  let(:administrateur) { administrateurs(:default_admin) }

  let(:expected_token) { 'd7e9c9f4c3ca00caadde31f50fd4521a' }

  let(:expected_sources) do
    {
      'cnaf' =>
      {
        'adresse' => ['identite', 'complementIdentite', 'complementIdentiteGeo', 'numeroRue', 'lieuDit', 'codePostalVille', 'pays'],
        'allocataires' => ['nomPrenom', 'dateDeNaissance', 'sexe'],
        'enfants' => ['nomPrenom', 'dateDeNaissance', 'sexe'],
        'quotient_familial' => ['quotientFamilial', 'annee', 'mois'],
      },
      'dgfip' =>
      {
        'declarant1' => ['dateNaissance', 'nom', 'nomNaissance', 'prenoms'],
        'declarant2' => ['dateNaissance', 'nom', 'nomNaissance', 'prenoms'],
        'echeance_avis' => ['dateEtablissement', 'dateRecouvrement'],
        'foyer_fiscal' => ['adresse', 'annee', 'nombreParts', 'nombrePersonnesCharge', 'situationFamille'],
        'agregats_fiscaux' => ['anneeImpots', 'anneeRevenus', 'impotRevenuNetAvantCorrections', 'montantImpot', 'revenuBrutGlobal', 'revenuFiscalReference', 'revenuImposable'],
        'complements' => ['situationPartielle', 'erreurCorrectif'],
      },
      'pole_emploi' => {
        'identite' => ['identifiant', 'civilite', 'nom', 'nomUsage', 'prenom', 'sexe', 'dateNaissance'],
        'adresse' => ['INSEECommune', 'codePostal', 'localite', 'ligneVoie', 'ligneComplementDestinataire', 'ligneComplementAdresse', 'ligneComplementDistribution', 'ligneNom'],
        'contact' => ['email', 'telephone', 'telephone2'],
        'inscription' => ['dateInscription', 'dateCessationInscription', 'codeCertificationCNAV', 'codeCategorieInscription', 'libelleCategorieInscription'],
      },
      'mesri' => {
        'identifiant' => ['ine'],
        'identite' => ['nom', 'prenom', 'dateNaissance'],
        'inscriptions' => ['statut', 'regime', 'dateDebutInscription', 'dateFinInscription', 'codeCommune'],
        'admissions' => ['statut', 'regime', 'dateDebutAdmission', 'dateFinAdmission', 'codeCommune'],
        'etablissements' => ['uai', 'nom'],
      },
    }
  end

  before do
    stub_const('API_PARTICULIER_URL', 'https://particulier.api.gouv.fr/api')
    Flipper.enable(:api_particulier)
  end

  context 'when an administrateur is logged in' do
    let(:procedure) do
      create(:procedure, :with_service, :with_instructeur, :with_zone,
             aasm_state: :brouillon,
             administrateurs: [administrateur],
             libelle: 'libellé de la procédure',
             path: 'libelle-de-la-procedure')
    end

    before { login_as administrateur.user, scope: :user }

    scenario 'it can enable api particulier' do
      visit admin_procedure_path(procedure)
      expect(page).to have_content('Configurer les jetons API')

      find('#api_token').click
      expect(page).to have_current_path(admin_procedure_jetons_path(procedure))

      click_on 'Ajouter un jeton API Particulier'

      expect(page).to have_current_path(api_particulier_admin_procedure_jetons_path(procedure))

      fill_in 'procedure_api_particulier_token', with: expected_token
      VCR.use_cassette('api_particulier/success/introspect') { click_on 'Enregistrer' }
      expect(page).to have_text('Le jeton a bien été mis à jour')
      expect(page).to have_current_path(admin_procedure_api_particulier_sources_path(procedure))

      ['allocataires', 'enfants'].each do |scope|
        within("#cnaf-#{scope}") do
          check('noms et prénoms')
          check('date de naissance')
          check('sexe')
        end
      end

      within('#cnaf-adresse') do
        check('identité')
        check('complément d’identité')
        check('complément d’identité géographique')
        check('numéro et rue')
        check('lieu-dit')
        check('code postal et ville')
        check('pays')
      end

      within('#cnaf-quotient_familial') do
        check('quotient familial')
        check('année')
        check('mois')
      end

      ['declarant1', 'declarant2'].each do |scope|
        within("#dgfip-#{scope}") do
          check('nom')
          check('nom de naissance')
          check('prénoms')
          check('date de naissance')
        end
      end

      scroll_to(find('#dgfip-echeance_avis'))
      within ('#dgfip-echeance_avis') do
        check('date de recouvrement')
        check("date d’établissement")
      end

      within('#dgfip-foyer_fiscal') do
        check('année')
        check('adresse')
        check('nombre de parts')
        check('situation familiale')
        check('nombre de personnes à charge')
      end

      within('#dgfip-agregats_fiscaux') do
        check('revenu brut global')
        check('revenu imposable')
        check('impôt sur le revenu net avant correction')
        check("montant de l’impôt")
        check('revenu fiscal de référence')
        check("année d’imposition")
        check('année des revenus')
      end

      within('#dgfip-complements') do
        check('erreur correctif')
        check('situation partielle')
      end

      within('#pole_emploi-identite') do
        check('identifiant')
        check('civilité')
        check('nom')
        check("nom d’usage")
        check('prénom')
        check('sexe')
        check('date de naissance')
      end

      within('#pole_emploi-adresse') do
        check('code INSEE de la commune')
        check('code postal')
        check('localité')
        check('voie')
        check('destinataire')
        check('adresse')
        check('distribution')
        check('nom')
      end

      within('#pole_emploi-contact') do
        check('adresse électronique')
        check('téléphone')
        check('téléphone 2')
      end

      within('#pole_emploi-inscription') do
        check("date d’inscription")
        check("date de cessation d’inscription")
        check('code de certification CNAV')
        check("code de catégorie d’inscription")
        check("libellé de catégorie d’inscription")
      end

      within('#mesri-identifiant') do
        check('INE')
      end

      within('#mesri-identite') do
        check('nom')
        check('prénom')
        check('date de naissance')
      end

      within('#mesri-inscriptions') do
        check('statut')
        check('régime')
        check("date de début d’inscription")
        check("date de fin d’inscription")
        check("code de la commune")
      end

      within('#mesri-admissions') do
        check('statut')
        check('régime')
        check("date de début d’admission")
        check("date de fin d’admission")
        check("code de la commune")
      end

      within('#mesri-etablissements') do
        check('UAI')
        check('nom')
      end

      click_on 'Enregistrer'

      procedure.reload

      expect(procedure.api_particulier_sources.keys).to contain_exactly('cnaf', 'dgfip', 'pole_emploi', 'mesri')
      expect(procedure.api_particulier_sources['cnaf'].keys).to contain_exactly('adresse', 'allocataires', 'enfants', 'quotient_familial')
      expect(procedure.api_particulier_sources['dgfip'].keys).to contain_exactly('declarant1', 'declarant2', 'echeance_avis', 'foyer_fiscal', 'agregats_fiscaux', 'complements')
      expect(procedure.api_particulier_sources['pole_emploi'].keys).to contain_exactly('identite', 'adresse', 'contact', 'inscription')
      expect(procedure.api_particulier_sources['mesri'].keys).to contain_exactly('identifiant', 'identite', 'inscriptions', 'admissions', 'etablissements')

      procedure.api_particulier_sources.each do |provider, scopes|
        scopes.each do |scope, fields|
          expect(fields).to match_array(expected_sources[provider][scope])
        end
      end

      visit champs_admin_procedure_path(procedure)

      add_champ
      select_type_de_champ('cnaf')
      fill_in 'Libellé du champ', with: 'libellé de champ'
      blur
      expect(page).to have_content('Formulaire enregistré')

      visit admin_procedure_path(procedure)
      find('#publish-procedure-link').click
      expect(find_field('procedure_path').value).to eq procedure.path
      fill_in 'procedure[lien_site_web]', with: 'http://some.website'
      within('form') { click_on 'Publier' }

      expect(page).to have_text('Votre démarche est désormais publiée !')
    end
  end

  context 'when a user is logged in' do
    let(:user) { create(:user) }
    let(:numero_allocataire) { '5843972' }
    let(:code_postal) { '92110' }
    let(:numero_fiscal) { '2097699999077' }
    let(:reference_avis) { '2097699999077' }
    let(:instructeur) { create(:instructeur) }
    let(:identifiant) { 'georges_moustaki_77' }
    let(:ine) { '090601811AB' }
    let(:api_particulier_token) { '29eb50b65f64e8e00c0847a8bbcbd150e1f847' }

    let(:procedure) do
      create(:procedure, :for_individual, :with_service, :published,
             libelle: 'libellé de la procédure',
             path: 'libelle-de-la-procedure',
             instructeurs: [instructeur],
             api_particulier_sources: expected_sources,
             api_particulier_token: api_particulier_token).tap do |p|
               p.active_revision.add_type_de_champ(type_champ: :cnaf, libelle: 'cnaf', mandatory: false)
               p.active_revision.add_type_de_champ(type_champ: :dgfip, libelle: 'dgfip', mandatory: false)
               p.active_revision.add_type_de_champ(type_champ: :pole_emploi, libelle: 'pole_emploi', mandatory: false)
               p.active_revision.add_type_de_champ(type_champ: :mesri, libelle: 'mesri', mandatory: false)
             end
    end

    before { login_as user, scope: :user }

    context 'CNAF' do
      scenario 'it can fill an cnaf champ', vcr: { cassette_name: 'api_particulier/success/composition_familiale' } do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        within('.individual-infos') do
          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')
        end

        within "#identite-form" do
          click_on 'Continuer'
        end

        fill_in 'Le numéro d’allocataire CAF', with: numero_allocataire
        fill_in 'Le code postal', with: 'wrong_code'

        dossier = Dossier.last
        cnaf_champ = dossier.project_champs_public.find(&:cnaf?)

        wait_until { cnaf_champ.reload.code_postal == 'wrong_code' }

        click_on 'Déposer le dossier'
        expect(page).to have_content("cnaf doit posséder 5 caractères")

        fill_in 'Le code postal', with: code_postal
        wait_until { cnaf_champ.reload.external_id.present? }

        perform_enqueued_jobs do
          wait_until { cnaf_champ.reload.fetched? }
        end
        click_on 'Déposer le dossier'

        expect(page).to have_current_path(merci_dossier_path(Dossier.last))

        perform_enqueued_jobs
        wait_until { cnaf_champ.reload.data.present? }

        visit demande_dossier_path(dossier)
        expect(page).to have_content(/Des données.*ont été reçues depuis la CAF/)

        log_out

        login_as instructeur.user, scope: :user

        visit instructeur_dossier_path(procedure, dossier)
        expect(page).to have_content('code postal et ville 92110 Clichy')
        expect(page).to have_content('identité Mr SNOW Eric')
        expect(page).to have_content('complément d’identité ne connait rien')
        expect(page).to have_content('numéro et rue 109 rue La Boétie')
        expect(page).to have_content('pays FRANCE')
        expect(page).to have_content('complément d’identité géographique au nord de paris')
        expect(page).to have_content('lieu-dit glagla')
        expect(page).to have_content('ERIC SNOW masculin 07 janvier 1991')
        expect(page).to have_content('SANSA SNOW féminin 15 janvier 1992')
        expect(page).to have_content('PAUL SNOW masculin 04 janvier 2018')
        expect(page).to have_content('1856 6 2021')
      end
    end

    context 'Pôle emploi' do
      let(:api_particulier_token) { '06fd8675601267d2988cbbdef56ecb0de1d45223' }

      scenario 'it can fill a Pôle emploi field', vcr: { cassette_name: 'api_particulier/success/situation_pole_emploi' } do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        within('.individual-infos') do
          fill_in('Prénom', with: 'Georges')
          fill_in('Nom', with: 'Moustaki')
        end
        within "#identite-form" do
          click_on 'Continuer'
        end

        fill_in "Identifiant", with: 'wrong code'

        dossier = Dossier.last
        pole_emploi_champ = dossier.project_champs_public.find(&:pole_emploi?)

        wait_until { pole_emploi_champ.reload.identifiant == 'wrong code' }

        clear_enqueued_jobs
        pole_emploi_champ.update(external_id: nil, identifiant: nil)

        fill_in "Identifiant", with: identifiant
        wait_until { pole_emploi_champ.reload.external_id.present? }

        perform_enqueued_jobs
        click_on 'Déposer le dossier'

        expect(page).to have_current_path(merci_dossier_path(Dossier.last))

        perform_enqueued_jobs
        wait_until { pole_emploi_champ.reload.data.present? }

        visit demande_dossier_path(dossier)
        expect(page).to have_content(/Des données.*ont été reçues depuis Pôle emploi/)

        log_out

        login_as instructeur.user, scope: :user

        visit instructeur_dossier_path(procedure, dossier)

        expect(page).to have_content('identifiant georges_moustaki_77')
        expect(page).to have_content('civilité M.')
        expect(page).to have_content('nom Moustaki')
        expect(page).to have_content("nom d’usage Moustaki")
        expect(page).to have_content('prénom Georges')
        expect(page).to have_content('sexe masculin')
        expect(page).to have_content('date de naissance 03 mai 1934')

        expect(page).to have_content('code INSEE de la commune 75118')
        expect(page).to have_content('code postal 75018')
        expect(page).to have_content('localité 75018 Paris')
        expect(page).to have_content('voie 3 rue des Huttes')
        expect(page).to have_content('nom MOUSTAKI')

        expect(page).to have_content('adresse électronique georges@moustaki.fr')
        expect(page).to have_content('téléphone 0629212921')

        expect(page).to have_content("date d’inscription 03 mai 1965")
        expect(page).to have_content("date de cessation d’inscription 03 mai 1966")
        expect(page).to have_content('code de certification CNAV VC')
        expect(page).to have_content("code de catégorie d’inscription 1")
        expect(page).to have_content("libellé de catégorie d’inscription PERSONNE SANS EMPLOI DISPONIBLE DUREE INDETERMINEE PLEIN TPS")

        expect(page).not_to have_content('téléphone 2')
        expect(page).not_to have_content('destinataire')
        expect(page).not_to have_content('complément d’identité')
        expect(page).not_to have_content('distribution')
      end
    end

    context 'MESRI', vcr: { cassette_name: 'api_particulier/success/etudiants' } do
      let(:api_particulier_token) { 'c6d23f3900b8fb4b3586c4804c051af79062f54b' }

      scenario 'it can fill a MESRI field' do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        within('.individual-infos') do
          fill_in('Prénom', with: 'Angela Claire Louise')
          fill_in('Nom', with: 'Dubois')
        end
        within "#identite-form" do
          click_on 'Continuer'
        end

        dossier = Dossier.last
        mesri_champ = dossier.project_champs_public.find(&:mesri?)

        fill_in "INE", with: ine
        perform_enqueued_jobs do
          wait_until { mesri_champ.reload.fetched? }
        end
        click_on 'Déposer le dossier'

        expect(page).to have_current_path(merci_dossier_path(Dossier.last))

        visit demande_dossier_path(dossier)
        expect(page).to have_content(/Des données.*ont été reçues depuis le MESRI/)

        log_out

        login_as instructeur.user, scope: :user

        visit instructeur_dossier_path(procedure, dossier)

        expect(page).to have_content('INE 090601811AB')

        expect(page).to have_content('nom DUBOIS')
        expect(page).to have_content('prénom Angela Claire Louise')
        expect(page).to have_content('date de naissance 24 août 1962')

        expect(page).to have_content('statut inscrit')
        expect(page).to have_content('régime formation continue')
        expect(page).to have_content("date de début d’inscription 01 septembre 2022")
        expect(page).to have_content("date de fin d’inscription 31 août 2023")
        expect(page).to have_content('code de la commune 75106')

        expect(page).to have_content('statut admis')
        expect(page).to have_content('régime formation continue')
        expect(page).to have_content("date de début d’admission 01 septembre 2021")
        expect(page).to have_content("date de fin d’admission 31 août 2022")
        expect(page).to have_content('code de la commune 75106')

        expect(page).to have_content('UAI 0751722P')
        expect(page).to have_content('nom Université Pierre et Marie Curie - UPCM (Paris 6)')
      end
    end

    context 'DGFiP' do
      scenario 'it can fill a DGFiP field', vcr: { cassette_name: 'api_particulier/success/avis_imposition' } do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        within('.individual-infos') do
          fill_in('Prénom', with: 'Karine')
          fill_in('Nom', with: 'FERRI')
        end
        within "#identite-form" do
          click_on 'Continuer'
        end

        fill_in 'Le numéro fiscal', with: numero_fiscal
        fill_in "La référence d’avis d’imposition", with: 'wrong_code'

        dossier = Dossier.last
        dgfip_champ = dossier.project_champs_public.find(&:dgfip?)

        wait_until { dgfip_champ.reload.reference_avis == 'wrong_code' }

        click_on 'Déposer le dossier'
        expect(page).to have_content(/dgfip doit posséder 13 ou 14 caractères/)

        fill_in "La référence d’avis d’imposition", with: reference_avis
        wait_until { dgfip_champ.reload.external_id.present? }

        perform_enqueued_jobs do
          wait_until { dgfip_champ.reload.fetched? }
        end
        click_on 'Déposer le dossier'

        expect(page).to have_current_path(merci_dossier_path(Dossier.last))

        perform_enqueued_jobs
        wait_until { dgfip_champ.reload.data.present? }

        visit demande_dossier_path(dossier)
        expect(page).to have_content(/Des données.*ont été reçues depuis la DGFiP/)

        log_out

        login_as instructeur.user, scope: :user

        visit instructeur_dossier_path(procedure, dossier)

        expect(page).to have_content('nom FERRI')
        expect(page).to have_content('nom de naissance FERRI')
        expect(page).to have_content('prénoms Karine')
        expect(page).to have_content('date de naissance 12/08/1978')

        expect(page).to have_content('date de recouvrement 09/10/2020')
        expect(page).to have_content("date d’établissement 07/07/2020")

        expect(page).to have_content('année 2020')
        expect(page).to have_content("adresse fiscale de l’année passée 13 rue de la Plage 97615 Pamanzi")
        expect(page).to have_content('nombre de parts 1')
        expect(page).to have_content('situation familiale Célibataire')
        expect(page).to have_content('nombre de personnes à charge 0')

        expect(page).to have_content('revenu brut global 38814')
        expect(page).to have_content('revenu imposable 38814')
        expect(page).to have_content('impôt sur le revenu net avant correction 38814')
        expect(page).to have_content("montant de l’impôt 38814")
        expect(page).to have_content('revenu fiscal de référence 38814')
        expect(page).to have_content("année d’imposition 2020")
        expect(page).to have_content('année des revenus 2020')

        expect(page).to have_content('situation partielle SUP DOM')

        expect(page).not_to have_content('erreur correctif')
      end
    end
  end
end
