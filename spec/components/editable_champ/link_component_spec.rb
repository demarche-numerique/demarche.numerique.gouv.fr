# frozen_string_literal: true

describe EditableChamp::LinkComponent, type: :component do
  let(:procedure) { create(:procedure, private_type_de_champs: [{ type: :link }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::EditableChampComponent.new(champ:, form:)
    end

    render_inline(component)
  end

  it 'renders in a callout the url as a link opening in a new tab, an edit button and the hidden edit form' do
    champ.update_columns(value: 'https://outil-metier.gouv.fr/dossiers/42')

    render

    expect(page).to have_css('.fr-callout h3 label', text: champ.libelle)
    expect(page).to have_css('a.fr-link[target="_blank"][rel="noopener noreferrer"][href="https://outil-metier.gouv.fr/dossiers/42"]', text: 'https://outil-metier.gouv.fr/dossiers/42')
    expect(page).to have_button('Modifier le lien')
    expect(page).to have_field(champ.focusable_input_id, type: 'url', with: 'https://outil-metier.gouv.fr/dossiers/42', visible: :hidden)
    expect(page).to have_button('Enregistrer', visible: :hidden)
    expect(page).to have_button('Annuler la modification du lien', visible: :hidden)
  end

  it 'renders only the input when empty' do
    render

    expect(page).to have_field(champ.focusable_input_id, type: 'url', visible: true)
    expect(page).to have_button('Enregistrer', visible: true)
    expect(page).to have_no_button('Modifier le lien')
    expect(page).to have_no_button('Annuler la modification du lien')
  end

  it 'never renders a saved value without an http(s) scheme as a link' do
    champ.update_columns(value: 'javascript:alert(1)')

    render

    expect(page).to have_field(champ.focusable_input_id, with: 'javascript:alert(1)')
    expect(page).to have_no_link
  end
end
