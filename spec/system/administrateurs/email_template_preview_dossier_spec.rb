# frozen_string_literal: true

describe 'As an administrateur I preview an email on the dossier of my choice', js: true do
  let(:procedure) { procedures.individual }
  let(:seeded) { procedure.dossiers.index_by(&:state) }
  # NFKC turns the state labels' non-breaking spaces into the plain ones Capybara reads
  let(:label) { -> (dossier) { "N° #{dossier.id} – Jeanne DUPONT – #{Dossier.human_attribute_name("state.#{dossier.state}").upcase}".unicode_normalize(:nfkc) } }

  before { login_as administrateurs.default.user, scope: :user }

  scenario 'the subject and the body follow the chosen dossier' do
    accepte, en_construction = seeded.values_at('accepte', 'en_construction')

    visit edit_admin_procedure_email_template_path(procedure, 'accepte')

    expect(page).to have_button(label.(accepte))
    expect(page).to have_css('#mail-subject-preview', text: "n° #{accepte.id}")

    select_react_option(label.(en_construction), from: "Dossier utilisé pour l’aperçu")

    expect(page).to have_css('#mail-subject-preview', text: "n° #{en_construction.id}")
    expect(page).to have_css("iframe.mail-preview-frame[srcdoc*='dossiers/#{en_construction.id}']", visible: :all)
  end
end
