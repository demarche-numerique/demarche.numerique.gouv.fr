# frozen_string_literal: true

describe 'Admin sticky procedure title', js: true do
  let(:administrateur) { create(:administrateur) }
  let(:procedure) do
    create(:procedure, :with_type_de_champ, administrateurs: [administrateur], libelle: 'Démarche test sticky')
  end

  before { login_as administrateur.user, scope: :user }

  context 'on the champs sub-page' do
    before { visit champs_admin_procedure_path(procedure) }

    it 'hides the sticky title by default' do
      expect(page).to have_css('.procedure-sticky-title', visible: :all)
      expect(page).not_to have_css('.procedure-sticky-title.visible')
    end

    it 'shows the sticky title after scroll past the breadcrumb' do
      execute_script("document.body.style.minHeight = '4000px'; window.scrollTo(0, 2000);")
      expect(page).to have_css('.procedure-sticky-title.visible', wait: 5)
      within('.procedure-sticky-title.visible') do
        expect(page).to have_text('Démarche test sticky')
        expect(page).to have_text(procedure.id.to_s)
      end
    end

    it 'hides the sticky title when scrolling back to top' do
      execute_script("document.body.style.minHeight = '4000px'; window.scrollTo(0, 2000);")
      expect(page).to have_css('.procedure-sticky-title.visible', wait: 5)

      execute_script('window.scrollTo(0, 0);')
      expect(page).not_to have_css('.procedure-sticky-title.visible', wait: 5)
    end
  end

  context 'on the procedure show page' do
    before { visit admin_procedure_path(procedure) }

    it 'shows the sticky title after scroll past the breadcrumb' do
      execute_script("document.body.style.minHeight = '4000px'; window.scrollTo(0, 2000);")
      expect(page).to have_css('.procedure-sticky-title.visible', wait: 5)
      within('.procedure-sticky-title.visible') do
        expect(page).to have_text('Démarche test sticky')
      end
    end
  end

  context 'when the draft has unpublished changes' do
    let(:procedure) do
      create(:procedure, :published, :with_type_de_champ, administrateurs: [administrateur], libelle: 'Démarche publiée')
    end

    before do
      procedure.draft_revision.add_type_de_champ(type_champ: TypeDeChamp.type_champs.fetch(:text), libelle: 'Nouveau champ')
      procedure.reload
      visit champs_admin_procedure_path(procedure)
    end

    it 'stacks the sticky title below the unpublished changes header after scroll' do
      expect(page).to have_css('.sticky-header-warning', visible: :all)

      execute_script('document.body.style.minHeight = "4000px"; window.scrollTo(0, 2000);')

      expect(page).to have_css('.sticky-header-warning')
      expect(page).to have_css('.procedure-sticky-title.visible', wait: 5)

      warning_top = evaluate_script("document.querySelector('.sticky-header-warning').getBoundingClientRect().top")
      title_top = evaluate_script("document.querySelector('.procedure-sticky-title').getBoundingClientRect().top")
      expect(warning_top).to be < title_top
    end
  end
end
