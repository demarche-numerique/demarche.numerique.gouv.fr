# frozen_string_literal: true

describe 'Prefill date champ from FranceConnect:', js: true do
  let(:user) { create(:user, france_connect_informations: [build(:france_connect_information)]) }
  let(:procedure) { create(:procedure, :published, :for_individual, :with_service, types_de_champ_public: [{ type: :date, libelle: 'Votre date de naissance' }]) }
  let(:tdc) { procedure.active_revision.root_types_de_champ_public.first }

  before do
    tdc.record.update!(options: { 'birthdate' => '1', 'prefill_with_france_connect_information' => '1' })
    login_as user, scope: :user
  end

  scenario 'usager voit le champ prérempli, instructeur voit le badge, le badge disparaît si modifié' do
    visit commencer_path(path: procedure.path)
    click_on 'Commencer la démarche'

    find('label', text: "Pour vous").click

    within "#identite-form" do
      click_button('Continuer')
    end

    dossier = procedure.dossiers.last
    expect(page).to have_current_path(brouillon_dossier_path(dossier))
    expect(page).to have_field('Votre date de naissance', with: '1976-02-24')

    champ = dossier.project_champ(tdc)
    expect(champ.value).to eq('1976-02-24')
    expect(champ.data['prefilled_from_france_connect_information']).to be true

    # Soumission du dossier (raccourci)
    dossier.passer_en_construction!
    logout(:user)

    # Côté instructeur : badge visible
    instructeur = create(:instructeur)
    procedure.defaut_groupe_instructeur.add(instructeur)
    login_as instructeur.user, scope: :user
    visit instructeur_dossier_path(procedure, dossier)
    expect(page).to have_text('Source : FranceConnect')

    # Si l'usager modifie la valeur, le flag disparaît
    champ.update!(value: '2000-01-01')
    expect(champ.reload.data['prefilled_from_france_connect_information']).to be_nil

    visit instructeur_dossier_path(procedure, dossier)
    expect(page).not_to have_text('Source : FranceConnect')
  end
end
