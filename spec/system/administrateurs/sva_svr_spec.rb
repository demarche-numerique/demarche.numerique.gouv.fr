# frozen_string_literal: true

describe 'Désactiver une règle SVA/SVR' do
  before_all { seed "cases/sva" }

  let(:admin) { administrateurs.default }
  let(:procedure) { procedures.sva }
  let!(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:, sva_svr_decision_on: 10.days.from_now.to_date) }

  before { login_as(admin.user, scope: :user) }

  scenario 'l’admin confirme sur un écran dédié, puis retrouve la configuration appliquée' do
    visit edit_admin_procedure_sva_svr_path(procedure)
    click_on 'Désactiver le SVA'

    expect(page).to have_content('Cette désactivation est définitive')
    expect(page).to have_content('1 dossier en instruction')
    expect(page).to have_content(I18n.l(10.days.from_now.to_date, format: :long))

    check 'J’ai compris : mes instructeurs devront traiter ce dossier eux-mêmes.'
    click_on 'Désactiver définitivement'

    expect(page).to have_content('Le SVA a été désactivé.')

    visit edit_admin_procedure_sva_svr_path(procedure)

    expect(page).to have_content("Le SVA, réglé sur 2 mois, est désactivé depuis le #{I18n.l(Date.current, format: :long)}")
    expect(page).not_to have_content('Fonctionnement du SVA/SVR')
  end
end
