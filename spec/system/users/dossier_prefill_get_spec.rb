# frozen_string_literal: true

describe 'Prefilling a dossier (with a GET request):', js: true do
  let(:password) { SECURE_PASSWORD }

  let(:types_de_champ_public) do
    [
      { type: :text },
      { type: :phone },
      { type: :siret },
      { type: :datetime },
      { type: :multiple_drop_down_list },
      { type: :epci },
      { type: :dossier_link },
      { type: :communes },
      { type: :address },
      { type: :repetition, children: [{ type: :text }, { type: :decimal_number }] },
    ]
  end
  let(:procedure) { create(:procedure, :for_individual, :published, opendata: true, types_de_champ_public:) }
  let(:dossier) { procedure.dossiers.last }
  let(:linked_dossier) { create(:dossier, :en_construction, procedure:) }
  let(:types_de_champ) { procedure.active_revision.types_de_champ_public }

  let(:type_de_champ_text) { types_de_champ[0] }
  let(:type_de_champ_phone) { types_de_champ[1] }
  let(:type_de_champ_siret) { types_de_champ[2] }
  let(:type_de_champ_datetime) { types_de_champ[3] }
  let(:type_de_champ_multiple_drop_down_list) { types_de_champ[4] }
  let(:type_de_champ_epci) { types_de_champ[5] }
  let(:type_de_champ_dossier_link) { types_de_champ[6] }
  let(:type_de_champ_commune) { types_de_champ[7] }
  let(:type_de_champ_address) { types_de_champ[8] }
  let(:type_de_champ_repetition) { types_de_champ[9] }

  let(:text_value) { "My Neighbor Totoro is the best movie ever" }
  let(:phone_value) { "invalid phone value" }
  let(:siret_value) { '30613890001294' }
  let(:datetime_value) { "2023-02-01T10:32" }
  let(:multiple_drop_down_list_values) {
    [
      type_de_champ_multiple_drop_down_list.drop_down_options.first,
      type_de_champ_multiple_drop_down_list.drop_down_options.last,
    ]
  }
  let(:epci_value) { ['01', '200029999'] }
  let(:dossier_link_value) { linked_dossier.id }
  let(:commune_value) { ['01540', '01457'] }
  let(:commune_libelle) { 'Vonnas (01540)' }
  let(:address_value) { "20 Avenue de Ségur 75007 Paris" }
  let(:sub_types_de_champ_repetition) { procedure.active_revision.children_of(type_de_champ_repetition) }
  let(:text_repetition_libelle) { sub_types_de_champ_repetition.first.libelle }
  let(:integer_repetition_libelle) { sub_types_de_champ_repetition.second.libelle }
  let(:text_repetition_value) { "First repetition text" }
  let(:integer_repetition_value) { "42" }
  let(:prenom_value) { 'Jean' }
  let(:nom_value) { 'Dupont' }
  let(:genre_value) { 'M.' }

  let(:entry_path) {
    commencer_path(
      path: procedure.path,
      "champ_#{type_de_champ_text.to_typed_id_for_query}" => text_value,
      "champ_#{type_de_champ_phone.to_typed_id_for_query}" => phone_value,
      "champ_#{type_de_champ_datetime.to_typed_id_for_query}" => datetime_value,
      "champ_#{type_de_champ_multiple_drop_down_list.to_typed_id_for_query}" => multiple_drop_down_list_values,
      "champ_#{type_de_champ_epci.to_typed_id_for_query}" => epci_value,
      "champ_#{type_de_champ_dossier_link.to_typed_id_for_query}" => dossier_link_value,
      "champ_#{type_de_champ_commune.to_typed_id_for_query}" => commune_value,
      "champ_#{type_de_champ_address.to_typed_id_for_query}" => address_value,
      "champ_#{type_de_champ_siret.to_typed_id_for_query}" => siret_value,
      "champ_#{type_de_champ_repetition.to_typed_id_for_query}" => [
        {
          "champ_#{sub_types_de_champ_repetition.first.to_typed_id_for_query}": text_repetition_value,
          "champ_#{sub_types_de_champ_repetition.second.to_typed_id_for_query}": integer_repetition_value,
        },
      ],
      "identite_prenom" => prenom_value,
      "identite_nom" => nom_value,
      "identite_genre" => genre_value
    )
  }

  before do
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\//)
      .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/etablissements.json'))

    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/unites_legales\/#{siret_value[0..8]}/)
      .to_return(status: 200, body: File.read('spec/fixtures/files/api_entreprise/entreprises.json'))
  end

  context 'when authenticated' do
    it_behaves_like "the user has got a prefilled dossier, owned by themselves" do
      let(:user) { create(:user, password: password) }

      before do
        visit "/users/sign_in"
        sign_in_with user.email, password
        visit entry_path

        click_on "Poursuivre mon dossier prérempli"
      end
    end
  end

  context 'when authenticated with existing dossier and session params (ie: reload the page)' do
    let(:user) { create(:user, password: password) }
    let(:dossier) { create(:dossier, :prefilled, procedure:, prefill_token: "token", user: nil) }
    let(:types_de_champ_public) { [{}] }

    before do
      dossier.champs.first.update(value: text_value)
      page.set_rack_session(prefill_token: "token")
      page.set_rack_session(prefill_params_digest: PrefillChamps.digest({ "champ_#{type_de_champ_text.to_typed_id}" => text_value }))

      visit "/users/sign_in"
      sign_in_with user.email, password

      visit commencer_path(
        path: procedure.path,
        "champ_#{type_de_champ_text.to_typed_id}" => text_value
      )

      click_on "Poursuivre mon dossier prérempli"
    end

    it "should not create a new dossier" do
      expect(Dossier.count).to eq(1)
      expect(dossier.reload.user).to eq(user)

      expect(page).to have_current_path(brouillon_dossier_path(dossier))
      expect(page).to have_field(type_de_champ_text.libelle, with: text_value)

      expect(page.get_rack_session[:prefill_token]).to be_nil
      expect(page.get_rack_session[:prefill_params_digest]).to be_nil
    end
  end

  context 'when unauthenticated' do
    before do
      allow(FranceConnectConfig).to receive(:client_config).and_return({ identifier: 'identifier' })
      allow(FranceConnectService).to receive(:enabled?).and_return(true)

      visit entry_path
    end

    context 'when the user signs in with email and password' do
      it_behaves_like "the user has got a prefilled dossier, owned by themselves" do
        let!(:user) { create(:user, password: password) }

        before do
          click_on "J’ai déjà un compte"
          sign_in_with user.email, password

          click_on "Poursuivre mon dossier prérempli"
        end
      end
    end

    context 'when the user signs up with email and password' do
      it_behaves_like "the user has got a prefilled dossier, owned by themselves" do
        let(:user_email) { generate :user_email }
        let(:user) { User.find_by(email: user_email) }

        before do
          click_on "Créer un compte #{APPLICATION_NAME}"

          sign_up_with user_email, password
          expect(page).to have_content "nous avons besoin de vérifier votre adresse électronique #{user_email}"

          click_confirmation_link_for user_email
          expect(page).to have_content('Votre compte a bien été confirmé.')

          click_on "Poursuivre mon dossier prérempli"
        end
      end
    end

    context 'when the user signs up with FranceConnect' do
      include EtablissementHelper

      let(:user) { User.last }
      let(:user_info) do
        {
          'sub' => 'blablabla',
          'given_name' => 'Prénom from FC',
          'family_name' => 'Nom from FC',
          'birthdate' => '20150821',
          'birthplace' => '1234',
          'birthcountry' => '12345',
          'gender' => 'M',
          'email' => 'EMAIL_from_fc@test.com',
        }
      end

      before do
        allow(FranceConnectService).to receive(:authorization_uri).and_return([france_connect_callback_path(code: "c0d3", state: 'state'), 'state', 'nonce'])
        allow(FranceConnectService).to receive(:retrieve_user_informations).and_return([user_info, 'id_token'])

        page.find('.fr-connect').click

        expect(page).to have_content("Choisissez votre adresse électronique de contact pour finaliser votre connexion")

        find('label', text: /Oui, utiliser .* comme adresse électronique de contact/).click

        click_on 'Valider'
        expect(page).to have_content('Vous avez un dossier prérempli')
        find('.fr-btn.fr-mb-2w', text: 'Poursuivre mon dossier prérempli', wait: 10).click
      end

      it "prefills dossier champs but not identity" do
        expect(dossier.user).to eq(user)

        expect(page).to have_current_path identite_dossier_path(procedure.dossiers.last)

        find('label', text: "Pour vous").click
        within('.individual-infos') do
          expect(page).to have_field('Prénom', with: "Prénom from FC", disabled: true)
          expect(page).to have_field('Nom', with: "Nom from FC", disabled: true)
        end
        within "#identite-form" do
          click_on 'Continuer'
        end

        expect(page).to have_current_path(brouillon_dossier_path(dossier))
        expect(page).to have_field(type_de_champ_text.libelle, with: text_value)
        expect(page).to have_field(type_de_champ_phone.libelle, with: phone_value)
        expect(page).to have_css('label', text: type_de_champ_phone.libelle)
        expect(page).to have_field(type_de_champ_siret.libelle, with: pretty_siret(siret_value))
        expect(page).to have_css('legend', text: type_de_champ_repetition.libelle)
        expect(page).to have_field(text_repetition_libelle, with: text_repetition_value)
        expect(page).to have_field(integer_repetition_libelle, with: integer_repetition_value)
        expect(page).to have_field(type_de_champ_datetime.libelle, with: datetime_value)
        expect(page).to have_css('legend', text: type_de_champ_multiple_drop_down_list.libelle)
        expect(page).to have_content(multiple_drop_down_list_values.first)
        expect(page).to have_content(multiple_drop_down_list_values.last)
        expect(page).to have_field("Le département de l’EPCI", with: epci_value.first)
        expect(page).to have_selector("option[value='#{epci_value.last}'][selected]")
        expect(page).to have_field(type_de_champ_dossier_link.libelle, with: dossier_link_value)
        expect(page).to have_field(type_de_champ_commune.libelle, with: commune_libelle)
        expect(page).to have_content(address_value.last)
        expect(page).to have_text("Recherche en cours pour le SIRET #{pretty_siret(siret_value)}")
      end
    end
  end
end
