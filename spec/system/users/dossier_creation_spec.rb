# frozen_string_literal: true

describe 'Creating a new dossier:', js: true do
  let(:user)  { create(:user) }
  let(:siret) { '41816609600051' }
  let(:siren) { siret[0...9] }

  context 'when the user is already signed in' do
    before do
      login_as user, scope: :user
    end

    context 'when the procedure has identification by individual' do
      let(:libelle) { "[title] with characters to escape : '@*^$" }
      let(:ask_birthday) { false }
      let(:expected_birthday) { nil }

      before do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        expect(page).to have_current_path identite_dossier_path(user.reload.dossiers.last)
      end

      shared_examples 'the user can create a new draft' do
        it do
          within "#identite-form" do
            click_button('Continuer')
          end

          expect(page).to have_current_path(brouillon_dossier_path(procedure.dossiers.last))
          expect(user.dossiers.first.individual.birthdate).to eq(expected_birthday)
        end
      end

      context 'when the birthday is asked' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, ask_birthday: true, libelle:) }
        let(:expected_birthday) { Date.new(1987, 12, 10) }

        before do
          find('label', text: "Pour vous").click
          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')
          fill_in 'Date de naissance', with: expected_birthday
        end

        it_behaves_like 'the user can create a new draft'
      end

      context 'when the birthday is not asked' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, ask_birthday: false, libelle:) }

        before do
          find('label', text: "Pour vous").click
          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')
        end

        it_behaves_like 'the user can create a new draft'
      end

      context 'when the gender is asked' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, no_gender: false, libelle:) }

        before do
          find('label', text: "Pour vous").click
          find('label', text: 'Madame').click
          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')
        end

        it_behaves_like 'the user can create a new draft'
      end

      context 'when user is connected via FranceConnect with incomplete identity' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, libelle:) }
        let(:user) { create(:user, france_connect_informations: [build(:france_connect_information, family_name: nil)]) }

        it 'allows the user to fill in missing fields and edit them later' do
          find('label', text: "Pour vous").click

          expect(page).to have_field('Prénom', disabled: false)
          expect(page).to have_field('Nom', disabled: false)
          expect(page).not_to have_text("par FranceConnect et ne peuvent pas être modifiées")

          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')

          within "#identite-form" do
            click_button('Continuer')
          end

          dossier = procedure.dossiers.last
          expect(page).to have_current_path(brouillon_dossier_path(dossier))
          expect(dossier.individual.reload.prenom).to eq('prenom')
          expect(dossier.individual.nom).to eq('nom')

          # Return to identity page to verify values are preserved
          visit identite_dossier_path(dossier)

          expect(page).to have_field('Prénom', with: 'prenom', disabled: false)
          expect(page).to have_field('Nom', with: 'nom', disabled: false)
        end
      end

      context 'when for tiers is disabled' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, for_tiers_enabled: false, libelle:) }

        before do
          fill_in('Prénom', with: 'prenom')
          fill_in('Nom', with: 'nom')
        end

        it_behaves_like 'the user can create a new draft'
      end

      context 'when individual fill dossier for a tiers' do
        let(:procedure) { create(:procedure, :published, :for_individual, :with_service, ask_birthday: false, libelle: libelle) }

        before do
          find('label', text: /Pour une autre personne/).click

          within('.mandataire-infos') do
            fill_in('Prénom', with: 'John')
            fill_in('Nom', with: 'Doe')
          end
        end

        it 'completes the form with email notification method selected' do
          expect(page).to have_text('Votre identité')
          expect(page).to have_text('Identité du bénéficiaire')

          within('.individual-infos') do
            fill_in('Prénom', with: 'prenom')
            fill_in('Nom', with: 'nom')

            find('label', text: /Informer le bénéficiaire par email/).click
            fill_in('dossier_individual_attributes_email', with: 'prenom.nom@mail.com')
          end

          within('.individual-infos') do
            find('label', text: 'Prénom').click # force focus out
          end

          within "#identite-form" do
            within '.suspect-email' do
              expect(page).to have_content("L’adresse électronique semble erronée Vouliez-vous écrire : prenom.nom@gmail.com ? Oui Non")
              click_button("Oui")
            end
            click_button("Continuer")
          end

          expect(page).to have_current_path(brouillon_dossier_path(procedure.dossiers.last))
          expect(procedure.dossiers.last.individual.reload.notification_method).to eq('email')
        end

        it 'completes the form with no notification method selected' do
          expect(page).to have_text('Identité du bénéficiaire')

          within('.individual-infos') do
            fill_in('Prénom', with: 'prenom')
            fill_in('Nom', with: 'nom')
          end

          within "#identite-form" do
            click_button('Continuer')
          end

          expect(page).to have_current_path(brouillon_dossier_path(procedure.dossiers.last))
          expect(procedure.dossiers.last.individual.reload.notification_method).to eq('no_notification')
        end
      end
    end

    context 'when identifying through SIRET' do
      let(:procedure) { create(:procedure, :published, :with_service, :with_type_de_champ) }
      let(:dossier) { procedure.dossiers.last }

      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/etablissements.json'))
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/unites_legales\/#{siren}/)
          .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/entreprises.json'))
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v2\/exercices\/#{siret}/)
          .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/exercices.json'))
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v2\/associations\/#{siret}/)
          .to_return(status: 404, body: '')
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v2\/effectifs_mensuels_acoss_covid\/2020\/02\/entreprise\/#{siren}/)
          .to_return(status: 404, body: '')
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v2\/effectifs_annuels_acoss_covid\/#{siren}/)
          .to_return(status: 404, body: '')
        allow_any_instance_of(APIEntrepriseToken).to receive(:roles).and_return([])
        allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
      end
      before { travel_to(Time.zone.local(2020, 3, 14)) }

      scenario 'the user can enter the SIRET of its etablissement and create a new draft' do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        expect(page).to have_current_path siret_dossier_path(dossier)
        expect(page).to have_content(procedure.libelle)

        fill_in 'Numéro SIRET', with: siret
        click_on 'Continuer'

        expect(page).to have_current_path(etablissement_dossier_path(dossier))
        expect(page).to have_content('Coiff Land, CoiffureLand')
        click_on 'Continuer avec ces informations'

        expect(page).to have_current_path(brouillon_dossier_path(dossier))
      end

      scenario 'the user is notified when its SIRET is invalid' do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        expect(page).to have_current_path(siret_dossier_path(dossier))
        expect(page).to have_content(procedure.libelle)

        fill_in 'Numéro SIRET', with: '0000'
        click_on 'Continuer'

        expect(page).to have_current_path(siret_dossier_path(dossier))
        expect(page).to have_content('Le champ « Siret » doit comporter exactement 14 chiffres. Exemple : 500 001 234 56789')
        expect(page).to have_field('Numéro SIRET', with: '0000')
      end
    end
  end

  context 'when the user is not signed in' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) { create(:procedure, :published) }
    scenario 'the user is an instructeur with untrusted device' do
      visit commencer_path(path: procedure.path)
      click_on "J’ai déjà un compte"
      sign_in_with(instructeur.email, instructeur.user.password, true)

      expect(page).to have_current_path(commencer_path(path: procedure.path))
    end
  end
end
