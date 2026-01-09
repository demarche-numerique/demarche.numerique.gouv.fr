# frozen_string_literal: true

describe 'Referentiel API:' do
  let(:zone) { create(:zone) }
  let(:user) { create(:user) }
  let(:administrateur) { create(:administrateur, user:) }
  let(:instructeur) { administrateur.instructeur }
  let(:service) { create(:service, administrateur:) }
  let!(:procedure) { create(:procedure, :for_individual, types_de_champ_public:, types_de_champ_private:, zones: [zone], service:, administrateurs: [administrateur], instructeurs: [instructeur]) }
  let(:referentiel_stable_id) { 21 }
  let(:prefill_text_stable_id) { 42 }
  let(:types_de_champ_public) { [] }
  let(:types_de_champ_private) { [] }
  before do
    login_as instructeur.user, scope: :user
  end

  context 'edges cases' do
    let(:types_de_champ_public) do
      [
        { type: :referentiel, libelle: "qu’importe" },
      ]
    end

    before { visit champs_admin_procedure_path(procedure) }

    scenario 'Setup as admin, fails with invalid url', js: true do
      click_on('Configurer le champ')

      find("#referentiel_url").fill_in(with: 'google.com')
      fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "focusout")

      expect(page).to have_content("n’est pas au format d’une URL, saisissez une URL valide ex https://api_1.ext/")
      find("#referentiel_url").fill_in(with: 'https://google.com')
      fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "focusout")

      expect(page).to have_content("doit être autorisée par notre équipe. Veuillez nous contacter par mail (contact@demarche.numerique.gouv.fr) et nous indiquer l’URL et la documentation de l’API que vous souhaitez intégrer.")
      find("#referentiel_url").fill_in(with: 'https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/')
      fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "focusout")

      expect(page).to have_content("Attention si vous appelez une API qui renvoie de la donnée personnelle, vous devez en informer votre DPO.")
    end

    scenario 'Setup as admin, back/forth auth does not changes preselected option', js: true do
      visit champs_admin_procedure_path(procedure)
      click_on('Configurer le champ')
      expect(page).to have_unchecked_field("Ajouter une méthode d’authentification")
      find("#referentiel_url").fill_in(with: 'google.com')
      fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "focusout")
      expect(page).to have_content("Le champ « URL de l’API » n’est pas au format d’une URL, saisissez une URL valide ex https://api_1.ext/")
      expect(page).to have_unchecked_field("Ajouter une méthode d’authentification")
    end
  end

  context 'when user fill in types_de_champ_public' do
    context 'when referentiel is exact match and prefill types_de_champ_public' do
      let(:prefill_boolean_stable_id) { 84 }
      let(:prefill_repetition_children_stable_id) { 168 }
      let(:types_de_champ_public) do
        [
          { type: :referentiel, libelle: 'Numero de bâtiment', stable_id: referentiel_stable_id },
          { type: :textarea, libelle: 'un autre champ' },
          { type: :text, libelle: 'prefill with $.statut', stable_id: prefill_text_stable_id },
          { type: :checkbox, libelle: 'prefill with $.is_active', stable_id: prefill_boolean_stable_id },
          {
            type: :repetition,
            libelle: "repetition",
            mandatory: false,
            children: [
              { type: :text, libelle: 'prefill with $.addresses[0].street', stable_id: prefill_repetition_children_stable_id },
            ],
          },
        ]
      end
      scenario 'Setup as admin, fill in as user, view it as instructeur', js: true, vcr: true do
        visit champs_admin_procedure_path(procedure)
        click_on('Configurer le champ')

        # configure connection
        VCR.use_cassette('referentiel/rnb_as_admin') do
          find("#referentiel_url").fill_in(with: 'https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/')
          find('label[for="referentiel_mode_exact_match"]').click
          fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "Saisir votre numero de bâtiment")
          fill_in("Exemple de saisie valide (affiché à l’usager et utilisé pour tester la requête)", with: "PG46YY6YWCX8")
          click_on('Étape suivante')
          wait_until { Referentiel.count == 1 }
          expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")
        end
        # check response and configure mapping
        click_on("Afficher la réponse récupérée à partir de la requête configurée")
        expect(page).to have_content("PG46YY6YWCX8") # check api was called

        #
        # map prefilled champs
        #
        custom_check("status")
        custom_check('is_active')
        custom_check('addresses-0-street')

        ## fill a custom libelle to display to user
        fill_in("type_de_champ_referentiel_mapping__.point.coordinates_libelle", with: "Coordonées du point")
        fill_in("type_de_champ_referentiel_mapping__.point.type_libelle", with: "Type de point")

        # submit and check values
        click_on('Étape suivante')
        expect(page).to have_content("La configuration du mapping a bien été enregistrée")
        referentiel_tdc = Referentiel.first.types_de_champ.first
        expect(referentiel_tdc.referentiel_mapping.dig("$.status", "prefill")).to eq("1")
        expect(referentiel_tdc.referentiel_mapping.dig("$.is_active", "prefill")).to eq("1")

        ##
        # choose prefill stable ids
        ###
        expect(page).to have_content("$.status")
        page.find("select[name='type_de_champ[referentiel_mapping][$.status][prefill_stable_id]']")
          .select('prefill with $.statut')
        # one boolean champ, nothing to select
        expect(page).to have_content("$.is_active")
        # choose another stable than the default one for the repetition
        expect(page).to have_content("$.addresses[0].street")
        page.find("select[name='type_de_champ[referentiel_mapping][$.addresses{0}.street][prefill_stable_id]']")
          .select('repetition - prefill with $.addresses[0].street')
        ##
        # choose display_usager display_instructeur
        ###
        # choose string value for usager and instructeur
        custom_check('point-type-display_usager')
        custom_check('point-type-display_instructeur')
        # choose array values only for usager
        custom_check('point-coordinates-display_usager')
        # choose string value only instructeur
        custom_check('shape-type-display_instructeur')
        click_on("Valider")

        wait_until { referentiel_tdc.reload .referentiel_mapping.dig("$.status", "prefill_stable_id").present? }
        # back to champs and check it's considered as configured
        expect(page).to have_content("Configuré")

        # check referentiel deep option exists
        expect(referentiel_tdc.referentiel_mapping.dig("$.status", "prefill_stable_id").to_s).to eq(prefill_text_stable_id.to_s)
        expect(referentiel_tdc.referentiel_mapping.dig("$.is_active", "prefill_stable_id").to_s).to eq(prefill_boolean_stable_id.to_s)

        publish(procedure)

        # start a dossier
        commencer(procedure)

        # fill in champ
        fill_in("Numero de bâtiment", with: "okokok")
        fill_in("un autre champ", with: "focus out for autosave")
        # update champ should not trigger an error and render a feedback
        expect(page).to have_content("Recherche en cours.")

        # but submitting before API response was fetched should trigger an error
        click_on("Déposer le dossier")
        expect(page).to have_content("En attente de réponse...")

        # reload page, if API response was not fetched, it's an error
        visit dossier_path(Dossier.last)
        expect(page).to have_content("En attente de réponse...")

        # and the page starts polling
        expect(page).to have_content("Recherche en cours.")

        # failed search
        VCR.use_cassette('referentiel/kthxbye_as_user') do
          fill_in("Numero de bâtiment", with: "kthxbye")
          fill_in("un autre champ", with: "focus out for autosave")

          perform_enqueued_jobs do
            # then the API response is fetched and tada... another error : bad data -> error
            expect(page).to have_content("Résultat introuvable. Vérifiez vos informations.")
          end
        end

        # success search
        VCR.use_cassette('referentiel/rnb_as_user') do
          fill_in("Numero de bâtiment", with: "PG46YY6YWCX8")
          perform_enqueued_jobs do
            expect(page).to have_content("Référence trouvée : PG46YY6YWCX8")
            dossier = Dossier.last

            # check prefill values in db
            expect(dossier.project_champs_public_all.find { it.stable_id.to_s == referentiel_stable_id.to_s }.value).to eq("PG46YY6YWCX8")
            expect(dossier.project_champs_public_all.find { it.stable_id.to_s == prefill_text_stable_id.to_s }.value).to eq("constructed")
            expect(dossier.project_champs_public_all.find { it.stable_id.to_s == prefill_boolean_stable_id.to_s }.value).to eq("true")
            repetition_values = dossier.project_champs_public_all.filter { it.stable_id.to_s == prefill_repetition_children_stable_id.to_s }.map(&:value)
            expect(repetition_values).to include("rue du puits")
            expect(repetition_values).to include("place de la bourse")

            # check webpage was also updated
            expect(page).to have_content("Donnée remplie automatiquement.", count: 4)

            # check display_usager populated web page too
            page.find("button.fr-accordion__btn").click
            within(".fr-fieldset__element .fr-collapse") do
              # now we check that the filled libelle for the mapping and the value are in the webpage, with the accordion
              expect(page).to have_content("Coordonées du point : -0.570505392116188, 44.841034137099996")
              expect(page).to have_content("Type de point : Point")
            end

            # check we can create a dossier
            click_on("Déposer le dossier")
            wait_until { Dossier.en_construction.count == 1 }

            created_dossier = Dossier.last
            # check data is also visible on demande page as an usager
            visit demande_dossier_path(created_dossier)
            expect(page).to have_content("Coordonées du point -0.570505392116188, 44.841034137099996")
            expect(page).to have_content("Type de point Point")
            expect(page).not_to have_content("$.shape.type") # not displayed to usager

            # check data is also visible on demande page as an usager
            visit instructeur_dossier_path(procedure, created_dossier)
            expect(page).to have_content("Sections du formulaire")
            expect(page).not_to have_content("Coordonées du point")
            expect(page).to have_content("Type de point")
            expect(page).to have_content("$.shape.type")
          end
        end
      end
    end

    context 'when referentiel is autocomplete and prefill types_de_champ_public' do
      let(:types_de_champ_public) do
        [
          { type: :referentiel, libelle: 'Numéro FINESS', stable_id: referentiel_stable_id },
          { type: :text, libelle: 'prefill with $.finess', stable_id: prefill_text_stable_id },
          { type: :date, libelle: 'prefill with $.date_extract_finess', stable_id: prefill_date_stable_id },
        ]
      end
      let(:prefill_date_stable_id) { 84 }

      scenario 'Setup as admin, fill in as user, view it as instructeur', js: true, vcr: true do
        visit champs_admin_procedure_path(procedure)
        click_on('Configurer le champ')

        # configure connection
        VCR.use_cassette('referentiel/datagouv-finess') do # referentiel is called at autocomplete setup
          find("#referentiel_url").fill_in(with: 'https://tabular-api.data.gouv.fr/api/resources/796dfff7-cf54-493a-a0a7-ba3c2024c6f3/data/?finess__contains={id}')
          find('label[for="referentiel_mode_autocomplete"]').click
          fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "Saisir votre finess")
          fill_in("Exemple de saisie valide (affiché à l’usager et utilisé pour tester la requête)", with: "010002699")
          click_on('Étape suivante')
          wait_until { Referentiel.count == 1 }
          expect(page).to have_content("Configuration de l’autocomplétion ")
        end

        VCR.use_cassette('referentiel/datagouv-finess') do # referentiel is called at mapping setup
          # configure datasource
          expect(page).not_to have_content("Propriétés qui seront affichées dans les autosuggestions")
          find("input[type=radio][name='referentiel[datasource]']").click
          expect(page).to have_content("Propriétés qui seront affichées dans les autosuggestions")

          # build tiptap template for autocomplete suggestion as `${$.finess} (${$.ej_rs})`
          page.find('button[title="$.finess (010002699)"]').click
          page.find('button[title="$.ej_rs (CENTRE MEDICAL REGINA)"]').click

          click_on('Étape suivante')
          expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")
        end

        # ensure tiptap template
        referentiel = Referentiel.last
        expect(referentiel.datasource).to eq("$.data")

        # referentiel.json_template['content'][0]['content']
        tiptap_template = referentiel.json_template['content'][0]['content']
        expect(tiptap_template.filter { it['type'] == "mention" }.map { it["attrs"]["id"] }).to match_array(%w[$.finess $.ej_rs])

        #
        # map prefilled champs
        #
        custom_check("data-0-finess")
        custom_check('data-0-date_extract_finess')

        click_on('Étape suivante')
        expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")

        # choose display usager/instructeur
        custom_check('data-0-adresse_nom_voie-display_usager')
        custom_check('data-0-adresse_nom_voie-display_instructeur')
        click_on("Valider")

        publish(procedure)
        commencer(procedure)

        # fill in autocomplete and select an option
        VCR.use_cassette('referentiel/datagouv-finess-partial-search') do
          referentiel_input = find("##{find(:label, text: 'Numéro FINESS')['for']}")
          referentiel_input.send_keys("01000269")

          # search and click on combobox
          expect(page).to have_content("010002699 CENTRE MEDICAL REGINA")
          find('.fr-ds-combobox__menu .fr-menu__list .fr-menu__item', text: "010002699 CENTRE MEDICAL REGINA").click

          expect(referentiel_input.value.strip).to match("010002699 CENTRE MEDICAL REGINA")

          dossier = Dossier.last

          # wait until selected key had been submitted to backend
          wait_until { dossier.reload.project_champs.find(&:referentiel).value&.match?(/010002699 CENTRE MEDICAL REGINA/) }

          # wait until refreshed with prefilled values
          expect(page).to have_content("Donnée remplie automatiquement.", count: 2)

          dossier.reload

          expect(dossier.project_champs.find { _1.stable_id.to_s == prefill_text_stable_id.to_s }.value).to eq("010002699")
          expect(dossier.project_champs.find { _1.stable_id.to_s == prefill_date_stable_id.to_s }.value).to eq("2004-12-31")

          expect(page).to have_content("$.data[0].adresse_nom_voie")
          expect(page).to have_content("GEORGES GIRERD")

          click_on("Déposer le dossier")
          wait_until { Dossier.en_construction.count == 1 }

          created_dossier = Dossier.last

          ## check as instructeur
          visit instructeur_dossier_path(procedure, created_dossier)
          expect(page).to have_content("$.data[0].adresse_nom_voie")
          expect(page).to have_content("GEORGES GIRERD")
        end
      end
    end

    context "when referentiel is exact match and prefill types_de_private" do
      let(:public_referentiel_stable_id) { 2 }
      let(:private_referentiel_stable_id) { 4 }
      let(:types_de_champ_public) do
        [
          {
            type: :referentiel,
            libelle: 'Numero de bâtiment public',
            stable_id: public_referentiel_stable_id,
            referentiel: create(:api_referentiel, :exact_match, :with_exact_match_response, url: "https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/"),
          },
        ]
      end
      let(:types_de_champ_private) do
        [
          { type: :text, libelle: 'prefilled by referentiel.public (with $.statut)', stable_id: prefill_by_public_referentiel_stable_id },
        ]
      end
      let(:prefill_by_public_referentiel_stable_id) { 8 }

      scenario 'prefill annotation : Setup as admin, fill in as user, view it as instructeur', js: true, vcr: true do
        visit champs_admin_procedure_path(procedure)
        click_on('Configurer le champ')

        # configure connection
        VCR.use_cassette('referentiel/rnb_as_admin') do
          click_on('Étape suivante')
          expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")
        end

        custom_check("status")
        ## fill a custom libelle to display to instructeur
        fill_in("type_de_champ_referentiel_mapping__.point.coordinates_libelle", with: "Coordonées du point")

        # submit and check values
        click_on('Étape suivante')
        expect(page).to have_content("La configuration du mapping a bien été enregistrée")
        referentiel_tdc = Referentiel.first.types_de_champ.first
        expect(referentiel_tdc.referentiel_mapping.dig("$.status", "prefill")).to eq("1")
        expect(page).to have_content("$.status")

        # prefill an annotation
        page.find("select[name='type_de_champ[referentiel_mapping][$.status][prefill_stable_id]']")
          .select('prefilled by referentiel.public (with $.statut)')
        ##
        # choose display_usager display_instructeur
        ###
        # choose string value for instructeur
        custom_check('point-type-display_instructeur')
        click_on("Valider")

        publish(procedure)
        commencer(procedure)

        dossier = Dossier.last
        # success search
        VCR.use_cassette('referentiel/rnb_as_user') do
          fill_in("Numero de bâtiment", with: "PG46YY6YWCX8")
          perform_enqueued_jobs do
            expect(page).to have_content("Référence trouvée : PG46YY6YWCX8")
            dossier.reload
            # check prefill values in db
            expect(dossier.project_champs_private_all.find { it.stable_id.to_s == prefill_by_public_referentiel_stable_id.to_s }.value).to eq("constructed")
          end
          click_on("Déposer le dossier")
        end
      end
    end
  end

  context 'when instructeur fill in types_de_champ_private' do
    context 'when referentiel is exact match' do
      let(:private_referentiel_stable_id) { 4 }
      let(:prefill_by_private_referentiel_stable_id) { 8 }
      let(:types_de_champ_private) do
        [
          {
            libelle: 'repetition',
            type: :repetition,
            mandatory: true,
            children: [
              {
                type: :referentiel,
                referentiel_id: create(:api_referentiel, :exact_match, :with_exact_match_response, url: "https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/").id,
                libelle: 'Numero de bâtiment private inside repetition',
                stable_id: private_referentiel_stable_id,
              },
              {
                type: :text,
                libelle: '$.statut',
                stable_id: prefill_by_private_referentiel_stable_id,
              },
            ],
          },
        ]
      end

      scenario 'Setup as admin, fill in annotations', js: true, vcr: true do
        visit annotations_admin_procedure_path(procedure)
        click_on('Configurer le champ')

        # configure connection
        VCR.use_cassette('referentiel/rnb_as_admin') do
          click_on('Étape suivante')
          expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")
        end

        ##
        # choose prefill stable ids
        ###
        expect(page).to have_content("$.status")
        custom_check("status")
        click_on('Étape suivante')

        # bind it to the expected champs
        expect(page).to have_content("La configuration du mapping a bien été enregistrée")

        # prefill an annotation
        page.find("select[name='type_de_champ[referentiel_mapping][$.status][prefill_stable_id]']")
          .select('repetition - $.statut')

        click_on("Valider")

        publish(procedure)

        dossier = create(:dossier, :en_construction, procedure:)

        visit annotations_privees_instructeur_dossier_path(dossier.procedure, dossier)

        expect(page).to have_content("en construction")
        VCR.use_cassette('referentiel/rnb_as_user') do
          fill_in("Numero de bâtiment private inside repetition", with: "PG46YY6YWCX8")
          perform_enqueued_jobs do
            expect(page).to have_content("Référence trouvée : PG46YY6YWCX8")
            dossier.reload
            # check prefill values in db
            expect(dossier.project_champs_private_all.find { it.stable_id.to_s == prefill_by_private_referentiel_stable_id.to_s }.value).to eq("constructed")
          end
        end
      end
    end

    context 'when referentiel is autocomplete' do
      let(:types_de_champ_private) do
        [
          {
            type: :repetition,
            libelle: 'repetition',
            mandatory: true,
            children: [
              { type: :referentiel, libelle: 'Numéro FINESS' },
              { type: :text, libelle: 'prefill with $.finess' },
              { type: :date, libelle: 'prefill with $.date_extract_finess' },
            ],
          },
        ]
      end

      scenario "Setup as admin, fill in annotations as instructeur", js: true, vcr: true do
        visit annotations_admin_procedure_path(procedure)
        click_on('Configurer le champ')

        # configure connection
        VCR.use_cassette('referentiel/datagouv-finess') do # referentiel is called at autocomplete setup
          find("#referentiel_url").fill_in(with: 'https://tabular-api.data.gouv.fr/api/resources/796dfff7-cf54-493a-a0a7-ba3c2024c6f3/data/?finess__contains={id}')
          find('label[for="referentiel_mode_autocomplete"]').click
          fill_in("Indications à fournir à l’usager concernant le format de saisie attendu", with: "Saisir votre finess")
          fill_in("Exemple de saisie valide (affiché à l’usager et utilisé pour tester la requête)", with: "010002699")
          click_on('Étape suivante')
          wait_until { Referentiel.count == 1 }
          expect(page).to have_content("Configuration de l’autocomplétion ")
        end

        # configuration autocomplete
        VCR.use_cassette('referentiel/datagouv-finess') do # referentiel is called at mapping setup
          # configure datasource
          expect(page).not_to have_content("Propriétés qui seront affichées dans les autosuggestions")
          find("input[type=radio][name='referentiel[datasource]']").click
          expect(page).to have_content("Propriétés qui seront affichées dans les autosuggestions")

          # build tiptap template for autocomplete suggestion as `${$.finess} (${$.ej_rs})`
          page.find('button[title="$.finess (010002699)"]').click
          page.find('button[title="$.ej_rs (CENTRE MEDICAL REGINA)"]').click

          click_on('Étape suivante')
          expect(page).to have_content("Pré remplissage des champs et/ou affichage des données récupérées")
        end

        #
        # map prefilled champs
        #
        custom_check("data-0-finess")
        custom_check('data-0-date_extract_finess')

        click_on('Étape suivante')
        click_on("Valider")

        publish(procedure)

        # fill in autocomplete and select an option
        dossier = create(:dossier, :en_construction, procedure:)

        visit annotations_privees_instructeur_dossier_path(dossier.procedure, dossier)

        VCR.use_cassette('referentiel/datagouv-finess-partial-search') do
          referentiel_input = find("##{find(:label, text: 'Numéro FINESS')['for']}")
          referentiel_input.send_keys("01000269")

          # search and click on combobox
          expect(page).to have_content("010002699 CENTRE MEDICAL REGINA")
          find('.fr-ds-combobox__menu .fr-menu__list .fr-menu__item', text: "010002699 CENTRE MEDICAL REGINA").click

          expect(referentiel_input.value.strip).to match("010002699 CENTRE MEDICAL REGINA")

          dossier = Dossier.last

          # wait until selected key had been submitted to backend
          wait_until { dossier.reload.project_champs_private_all.find(&:repetition?).rows.first.find(&:referentiel?).value&.match?(/010002699 CENTRE MEDICAL REGINA/) }

          # wait until refreshed with prefilled values
          expect(page).to have_content("Donnée remplie automatiquement.", count: 2)
          expect(dossier.reload.project_champs_private_all.find(&:repetition?).rows.first.map(&:value)).to include("010002699")
        end
      end
    end
  end

  private

  def publish(procedure)
    # now procedure should be publishable
    visit admin_procedure_path(procedure)
    expect(page).to have_content("Publier")
    click_on("Publier")

    # publish
    fill_in("procedure[path]", with: "htxbye")
    fill_in("procedure[lien_site_web]", with: "google.fr")
    within("form") do
      click_on("publish")
    end
    wait_until { procedure.reload.published_revision.present? }
  end

  def commencer(procedure)
    # start a dossier
    visit commencer_path(procedure.path)
    click_on("Commencer la démarche")
    expect(page).to have_content("Votre identité")
    fill_in("Prénom", with: "Jeanne")
    fill_in("Nom", with: "Dupont")
    within "#identite-form" do
      click_on 'Continuer'
    end
    expect(page).to have_content("Identité enregistrée")
  end
end
