# frozen_string_literal: true

describe 'Reorder procedures with a keyboard and a screen reader', js: true do
  let(:instructeur) { instructeurs.default }
  # seeds give 2 procedures; a third one adds a middle position where no button gets disabled
  before { create(:procedure, :published, instructeurs: [instructeur]) }

  before do
    login_as instructeur.user, scope: :user
    visit instructeur_procedures_path
    click_on 'Personnaliser'
  end

  def names = all('ol > li [id$="-libelle"]').map(&:text)

  def button(name)
    page.driver.with_playwright_page { it.get_by_role('button', name:, exact: true) }
  end

  def focused?(locator) = locator.evaluate('el => el === document.activeElement')

  scenario 'each move is announced and keeps the focus' do
    initial = names
    first, second = initial
    last = initial.last
    total = initial.size

    # the procedure name comes before its buttons in the DOM
    expect(page).to have_css("ol > li:first-child [id$='-libelle'] ~ .order-first button", count: 2)

    button("Déplacer vers le haut #{second}").press('Enter')
    expect(page).to have_css('[role=status]', text: "Déplacée à la position 1 sur #{total}", visible: :all)
    expect(names.first(2)).to eq([second, first])
    # the up button is now disabled: focus goes to the other button of the same procedure
    expect(focused?(button("Déplacer vers le bas #{second}"))).to be(true)

    button("Déplacer vers le bas #{second}").press('Enter')
    expect(page).to have_css('[role=status]', text: "Déplacée à la position 2 sur #{total}", visible: :all)
    expect(names).to eq(initial)
    expect(focused?(button("Déplacer vers le bas #{second}"))).to be(true)

    button("Déplacer vers le haut #{last}").press('Enter')
    # same message as the previous move: wait for the move itself
    expect(page).to have_css("ol > li:nth-child(#{total - 1})", text: last)
    expect(page).to have_css('[role=status]', text: "Déplacée à la position #{total - 1} sur #{total}", visible: :all)
    expect(focused?(button("Déplacer vers le haut #{last}"))).to be(true)

    button("Déplacer vers le bas #{last}").press('Enter')
    expect(page).to have_css('[role=status]', text: "Déplacée à la position #{total} sur #{total}", visible: :all)
    expect(names).to eq(initial)
    expect(focused?(button("Déplacer vers le haut #{last}"))).to be(true)

    click_on 'Valider'
    expect(page).to have_text('L’ordre des démarches a été mis à jour.')
  end
end
