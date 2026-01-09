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
      let(:procedure) { create(:procedure, :published, :for_individual, :with_service, ask_birthday: ask_birthday, libelle: libelle) }
      let(:ask_birthday) { false }
      let(:expected_birthday) { nil }

      before do
        visit commencer_path(path: procedure.path)
        click_on 'Commencer la démarche'

        expect(page).to have_current_path identite_dossier_path(user.reload.dossiers.last)
        expect(page).to have_title(libelle)

        fill_in('Prénom', with: 'prenom', visible: true)
        fill_in('Nom', with: 'nom', visible: true)
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
        let(:ask_birthday) { true }
        let(:expected_birthday) { Date.new(1987, 12, 10) }

        before do
          fill_in 'Date de naissance', with: expected_birthday
        end

        context 'when the birthday is asked' do
          it_behaves_like 'the user can create a new draft'
        end
      end

      context 'when the birthday is not asked' do
        let(:ask_birthday) { false }
        let(:expected_birthday) { nil }
        it_behaves_like 'the user can create a new draft'
      end

      context 'when individual fill dossier for a tiers' do
        it 'completes the form with email notification method selected' do
          find('label', text: 'Pour un bénéficiaire : membre de la famille, proche, mandant, professionnel en charge du suivi du dossier…').click
          within('.mandataire-infos') do
            fill_in('Prénom', with: 'John')
            fill_in('Nom', with: 'Doe')
          end

          within('.individual-infos') do
            fill_in('Prénom', with: 'prenom')
            fill_in('Nom', with: 'nom')
          end

          find('label', text: 'Par adresse électronique').click
          fill_in('dossier_individual_attributes_email', with: 'prenom.nom@mail.com')
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

          expect(procedure.dossiers.last.individual.notification_method == 'email')
          expect(page).to have_current_path(brouillon_dossier_path(procedure.dossiers.last))
        end

        it 'completes the form with no notification method selected' do
          find('label', text: 'Pour un bénéficiaire : membre de la famille, proche, mandant, professionnel en charge du suivi du dossier…').click

          within('.mandataire-infos') do
            fill_in('Prénom', with: 'John')
            fill_in('Nom', with: 'Doe')
          end

          within('.individual-infos') do
            fill_in('Prénom', with: 'prenom')
            fill_in('Nom', with: 'nom')
          end

          find('label', text: 'Pas de notification').click
          within "#identite-form" do
            click_button('Continuer')
          end

          expect(procedure.dossiers.last.individual.notification_method.empty?)
          expect(page).to have_current_path(brouillon_dossier_path(procedure.dossiers.last))
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
