# frozen_string_literal: true

describe 'Administrateurs can edit procedures', js: true do
  include Logic

  let(:procedure) { create(:procedure, administrateurs: [create(:administrateur)]) }
  before do
    login_as procedure.administrateurs.first.user, scope: :user
  end

  scenario 'setup eligibilite' do
    # explain no champ compatible
    visit admin_procedure_path(procedure)
    expect(page).to have_content("Désactivé")

    # explain which champs are compatible
    visit edit_admin_procedure_ineligibilite_rules_path(procedure)
    expect(page).to have_content("Inéligibilité des dossiers")
    expect(page).to have_content("Pour configurer l’inéligibilité des dossiers, votre formulaire doit comporter au moins un champ supportant les conditions d’inéligibilité. Il vous faut donc ajouter au moins un des champs suivant à votre formulaire : ")
    click_on "Ajouter un champ supportant les conditions d’inéligibilité"

    # setup a compatible champ
    expect(page).to have_content('Champs du formulaire')
    click_on 'Ajouter un champ'
    select "Oui/Non"
    fill_in "Libellé du champ", with: "Un champ oui non"
    click_on "Revenir à l’écran de gestion"
    procedure.reload
    first_tdc = procedure.draft_revision.types_de_champ.first
    # back to procedure dashboard, explain you can set it up now
    expect(page).to have_content('À configurer')
    visit edit_admin_procedure_ineligibilite_rules_path(procedure)

    # setup rules and stuffs
    expect(page).to have_content("Inéligibilité des dossiers")
    fill_in "Message d’inéligibilité", with: "vous n’etes pas eligible"
    find('label', text: 'Bloquer le dépôt des dossiers répondant à des conditions d’inéligibilité').click
    click_on "Ajouter une règle d’inéligibilité"
    all('select').first.select 'Un champ oui non'
    click_on 'Enregistrer'

    # rules are setup
    wait_until { procedure.reload.draft_revision.ineligibilite_enabled == true }
    expect(procedure.draft_revision.ineligibilite_message).to eq("vous n’etes pas eligible")
    expect(procedure.draft_revision.ineligibilite_rules).to eq(ds_eq(champ_value(first_tdc.stable_id), constant(true)))
  end
end
