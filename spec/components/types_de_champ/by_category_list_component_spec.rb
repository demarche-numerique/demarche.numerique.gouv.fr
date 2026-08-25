# frozen_string_literal: true

describe TypesDeChamp::ByCategoryListComponent, type: :component do
  before { render_inline(described_class.new(types: TypeDeChamp.conditionable_types)) }

  it 'lists the types grouped by category, in the editor order' do
    expect(page.all('li').map(&:text)).to eq([
      "« Adresse », « Commune française actuelle », « Département », « Région », « Pays », « EPCI »",
      "« Nombre décimal », « Nombre entier »",
      "« Case à cocher seule », « Choix simple », « Choix multiple », « Oui/Non »",
      "« Champ pré-rempli »",
    ])
  end
end
