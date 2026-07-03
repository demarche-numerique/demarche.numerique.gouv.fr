# frozen_string_literal: true

describe 'Quotient familial piece justificative upload', js: true do
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_public: [{ type: :quotient_familial }]) }

  before do
    Flipper.enable(:quotient_familial_type_de_champ, procedure)
    login_as user, scope: :user
  end

  scenario 'usager uploads a piece justificative when QF data is not fetched' do
    visit commencer_path(path: procedure.path)
    click_on 'Commencer la démarche'

    find('label', text: "Pour vous").click
    within('.individual-infos') do
      fill_in('Prénom', with: 'Jean')
      fill_in('Nom', with: 'Dupont')
    end

    within "#identite-form" do
      click_on 'Continuer'
    end

    expect(page).to have_text('Justificatif de quotient familial')

    within('.editable-champ-quotient_familial') do
      find('input[type=file]', visible: false).attach_file(Rails.root.join('spec/fixtures/files/piece_justificative_0.pdf'))
      expect(page).to have_text('piece_justificative_0.pdf', wait: 5)
    end

    dossier = Dossier.last
    champ = dossier.champ_data.find { _1.is_type?('quotient_familial') }
    wait_until { champ.reload.piece_justificative_file.attached? }

    expect(champ.piece_justificative_file).to be_attached

    # Test de suppression
    within('.editable-champ-quotient_familial') do
      click_on 'Supprimer le fichier piece_justificative_0.pdf'
    end

    wait_until { !champ.reload.piece_justificative_file.attached? }
    expect(champ.piece_justificative_file.attached?).to be(false)
  end
end
