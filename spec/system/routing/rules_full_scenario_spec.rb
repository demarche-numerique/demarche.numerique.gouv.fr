# frozen_string_literal: true

describe 'The routing with rules', js: true do
  let(:password) { SECURE_PASSWORD }

  let(:procedure) do
    create(:procedure, :with_service, :for_individual, :with_zone, types_de_champ_public: [
      { type: :text, libelle: 'un premier champ text', mandatory: false },
      { type: :drop_down_list, libelle: 'Spécialité', options: ["littéraire", "scientifique", "artistique"], mandatory: false },
    ])
  end
  let(:administrateur) { create(:administrateur, procedures: [procedure]) }
  let(:scientifique_user) { create(:user, password: password) }
  let(:litteraire_user) { create(:user, password: password) }
  let(:artistique_user) { create(:user, password: password) }

  before do
    procedure.defaut_groupe_instructeur.instructeurs << administrateur.instructeur
  end

  scenario 'Configuration automatique du routage' do
    steps_to_routing_configuration

    choose('Automatique', allow_label_click: true)
    click_on 'Continuer'

    expect(page).to have_text('Configuration automatique')

    choose('Spécialité', allow_label_click: true)
    click_on 'Créer les groupes'

    expect(page).to have_text('Gestion des groupes')
    expect(page).to have_text('3 groupes')
    expect(page).not_to have_text('à configurer')

    within("#routing-mode-modal") { click_on "Fermer" }

    click_on 'littéraire'
    expect(page).to have_select("groupe_instructeur[condition_form][rows][][targeted_champ]", selected: "Spécialité")
    expect(page).to have_select("groupe_instructeur[condition_form][rows][][value]", selected: "littéraire")

    click_on 'Revenir à la liste'
    click_on 'scientifique'

    expect(page).to have_select("groupe_instructeur[condition_form][rows][][targeted_champ]", selected: "Spécialité")
    expect(page).to have_select("groupe_instructeur[condition_form][rows][][value]", selected: "scientifique")
  end

  scenario 'Configuration manuelle du routage' do
    steps_to_routing_configuration

    choose('Manuelle', allow_label_click: true)
    click_on 'Continuer'

    expect(page).to have_text('Gestion des groupes')
    expect(page).to have_text('aucune règle')

    # close modal
    expect(page).to have_selector("#routing-mode-modal", visible: true)
    within("#routing-mode-modal") { click_on "Fermer" }
    expect(page).to have_selector("#routing-mode-modal", visible: false)

    # update defaut groupe
    click_on 'Groupe 1 (à renommer et configurer)'
    expect(page).to have_text('Paramètres du groupe')
    fill_in 'Nom du groupe', with: 'littéraire'
    click_on 'Renommer'
    expect(page).to have_text('Le nom est à présent « littéraire ». ')

    # add victor to littéraire groupe
    select_combobox('Emails', 'victor@gouv.fr', custom_value: true)

    perform_enqueued_jobs { click_on 'Affecter' }
    expect(page).to have_text("L’instructeur victor@gouv.fr a été ajouté")

    victor = User.find_by(email: 'victor@gouv.fr').instructeur

    # add alain to littéraire groupe
    select_combobox('Emails', 'alain@gouv.fr', custom_value: true)

    perform_enqueued_jobs { click_on 'Affecter' }
    expect(page).to have_text("L’instructeur alain@gouv.fr a été ajouté")

    alain = User.find_by(email: 'alain@gouv.fr').instructeur

    # add inactive groupe
    visit admin_procedure_groupe_instructeurs_path(procedure)
    click_on 'Ajouter un groupe'
    within('#modal-add-groupe') do
      fill_in 'Nouveau groupe', with: 'non visible car inactif'
      click_on 'Ajouter'
    end
    expect(page).to have_text('Le groupe d’instructeurs « non visible car inactif » a été créé. ')
    check("Groupe inactif", allow_label_click: true)

    # # add scientifique groupe
    click_on 'Revenir à la liste'
    click_on 'Groupe 2 (à renommer et configurer)'
    fill_in 'Nom du groupe', with: 'scientifique'
    click_on 'Renommer'
    expect(page).to have_text('Le nom est à présent « scientifique ». ')

    # add marie to scientifique groupe
    select_combobox('Emails', 'marie@gouv.fr', custom_value: true)

    perform_enqueued_jobs { click_on 'Affecter' }
    expect(page).to have_text("L’instructeur marie@gouv.fr a été ajouté")

    marie = User.find_by(email: 'marie@gouv.fr').instructeur

    # add superwoman to scientifique groupe
    select_combobox('Emails', 'alain@gouv.fr', custom_value: true)
    perform_enqueued_jobs { click_on 'Affecter' }
    expect(page).to have_text("L’instructeur alain@gouv.fr a été ajouté")

    # add routing rules
    within('.target select') { select('Spécialité') }
    within('.value select') { select('scientifique') }

    click_on 'Revenir à la liste'

    click_on 'littéraire'

    within('.target select') { select('Spécialité') }
    within('.value select') { select('scientifique') }

    expect(page).to have_text('règle déjà attribuée à scientifique')

    within('.target select') { select('Spécialité') }
    within('.value select') { select('littéraire') }

    expect(page).not_to have_text('règle déjà attribuée à scientifique')

    procedure.groupe_instructeurs.where(closed: false).each { |gi| wait_until { gi.reload.routing_rule.present? } }

    # add a group without routing rules
    visit admin_procedure_groupe_instructeurs_path(procedure)
    click_on 'Ajouter un groupe'
    within('#modal-add-groupe') do
      fill_in 'Nouveau groupe', with: 'artistique'
      click_on 'Ajouter'
    end
    expect(page).to have_text('Le groupe d’instructeurs « artistique » a été créé. ')
    expect(procedure.groupe_instructeurs.count).to eq(4)

    # add contact_information to all groupes instructeur
    procedure.groupe_instructeurs.each { |gi| gi.update!(contact_information: create(:contact_information)) }

    # publish
    publish_procedure(procedure)
    log_out

    # 3 users fill a dossier in each group
    user_send_dossier(scientifique_user, 'scientifique')
    user_send_dossier(litteraire_user, 'littéraire')
    user_send_dossier(artistique_user, 'artistique')

    perform_enqueued_jobs(only: DossierIndexSearchTermsJob)

    # the litteraires instructeurs only manage the litteraires dossiers
    register_instructeur_and_log_in(victor.email)
    click_on(procedure.libelle, visible: true)
    expect(page).to have_text(litteraire_user.email)
    expect(page).not_to have_text(scientifique_user.email)

    # the search only show litteraires dossiers
    fill_in 'q', with: scientifique_user.email
    find('.fr-search-bar .fr-btn').click
    expect(page).to have_text('Aucun dossier')

    # weird bug, capabary appends text instead of replaces it
    # see https://github.com/redux-form/redux-form/issues/686
    fill_in('q', with: litteraire_user.email, fill_options: { clear: :backspace })
    find('.fr-search-bar .fr-btn').click
    expect(page).to have_text('1 dossier trouvé')

    ## and the result is clickable
    click_on litteraire_user.email
    expect(page).to have_current_path(instructeur_dossier_path(procedure, litteraire_user.dossiers.first))

    # follow the dossier
    click_on 'Suivre'

    log_out

    # the scientifiques instructeurs only manage the scientifiques dossiers
    register_instructeur_and_log_in(marie.email)
    click_on(procedure.libelle, visible: true)
    expect(page).not_to have_text(litteraire_user.email)
    expect(page).to have_text(scientifique_user.email)

    # follow the dossier
    click_on scientifique_user.email
    click_on 'Suivre'

    log_out

    # litteraire_user change its dossier
    visit new_user_session_path
    sign_in_with litteraire_user.email, password

    click_on litteraire_user.dossiers.first.procedure.libelle, match: :first
    click_on 'Modifier le dossier'

    fill_in litteraire_user.dossiers.first.project_champs_public.first.libelle, with: 'some value'
    wait_for_autosave

    click_on 'Déposer les modifications'

    log_out

    # the litteraires instructeurs should have a notification
    visit new_user_session_path
    sign_in_with victor.user.email, password

    ## on the procedures list
    expect(page).to have_current_path(instructeur_procedures_path)
    expect(find('.procedure-stats')).to have_css('span.notifications')

    ## on the dossiers list
    click_on(procedure.libelle, visible: true)
    expect(page).to have_current_path(instructeur_procedure_path(procedure))
    expect(find('nav.fr-tabs')).to have_css('span.notifications')

    ## on the dossier itself
    click_on 'suivis par moi'
    click_on litteraire_user.email
    expect(page).to have_current_path(instructeur_dossier_path(procedure, litteraire_user.dossiers.first, statut: :suivis))
    expect(page).to have_text('Annotations privées')
    expect(find('.fr-tabs')).to have_css('span.notifications')
    log_out

    # the scientifiques instructeurs should not have a notification
    visit new_user_session_path
    sign_in_with marie.user.email, password

    expect(page).to have_current_path(instructeur_procedures_path)
    expect(find('.procedure-stats')).not_to have_css('span.notifications')
    log_out

    # the instructeurs who belong to scientifique AND litteraire groups manage scientifique and litteraire dossiers
    register_instructeur_and_log_in(alain.email)
    visit instructeur_procedure_path(procedure, statut: 'tous')
    expect(page).to have_text(litteraire_user.email)
    expect(page).to have_text(scientifique_user.email)

    # follow the dossier
    click_on scientifique_user.email
    click_on 'Suivre'

    visit instructeur_procedure_path(procedure, statut: 'tous')
    click_on litteraire_user.email
    click_on 'Suivre'
    log_out

    # scientifique_user updates its group
    user_update_group(scientifique_user, 'littéraire')

    # the instructeurs who belong to scientifique AND litteraire groups should have a notification
    visit new_user_session_path
    sign_in_with alain.user.email, password

    expect(page).to have_current_path(instructeur_procedures_path)
    expect(find('.procedure-stats')).to have_css('span.notifications')
  end

  def publish_procedure(procedure)
    click_on procedure.libelle
    find('#publish-procedure-link').click
    fill_in 'procedure[lien_site_web]', with: 'http://some.website'
    within('form') { click_on 'Publier' }

    expect(page).to have_text('Votre démarche est désormais publiée !')
  end

  def user_send_dossier(user, groupe)
    login_as user, scope: :user
    visit commencer_path(path: procedure.reload.path)
    click_on 'Commencer la démarche'

    fill_in('Prénom', with: 'prenom', visible: true)
    fill_in('Nom', with: 'Nom', visible: true)
    within "#identite-form" do
      click_button('Continuer')
    end

    # the old system should not be present
    expect(page).not_to have_selector("#dossier_groupe_instructeur_id")

    dossier = user.dossiers.first

    expect(dossier.groupe_instructeur_id).to be_nil
    expect(page).to have_text(procedure.service.nom)

    choose(groupe, allow_label_click: true)
    wait_for_autosave

    expect(dossier.reload.groupe_instructeur_id).not_to be_nil
    expect(page).to have_text(dossier.service_or_contact_information.nom)
    expect(page).not_to have_text(procedure.service.nom)

    click_on 'Déposer le dossier'
    expect(page).to have_text('Merci')

    log_out
  end

  def user_update_group(user, new_group)
    login_as user, scope: :user
    visit dossiers_path
    click_on user.dossiers.first.procedure.libelle, match: :first
    click_on "Modifier le dossier"

    choose(new_group, allow_label_click: true)
    wait_for_autosave

    expect(page).to have_text(new_group)

    click_on 'Déposer les modifications'

    log_out
  end

  def register_instructeur_and_log_in(email)
    confirmation_email = emails_sent_to(email).reverse
      .find { |m| m.subject.starts_with?('Vous avez été ajouté(e) au groupe') }
    token_params = confirmation_email.body.match(/token=[^"]+/)

    visit "users/activate?#{token_params}"
    fill_in :user_password, with: password
    click_button 'Créer un compte'

    expect(page).to have_text('Mot de passe enregistré')
  end

  def steps_to_routing_configuration
    login_as administrateur.user, scope: :user
    visit admin_procedure_path(procedure.id)
    find('#groupe-instructeurs').click

    click_on 'Options'
    expect(page).to have_text('Options concernant l’instruction')
    click_on 'Configurer le routage'
    expect(page).to have_text('Choix du type de configuration')
  end
end
