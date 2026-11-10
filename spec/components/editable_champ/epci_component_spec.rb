# frozen_string_literal: true

describe EditableChamp::EpciComponent, type: :component do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :epci }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::EditableChampComponent.new(champ:, form:)
    end

    render_inline(component)
  end

  it 'shows « Sélectionnez » when the saved EPCI is not in the list of the departement' do
    champ.update_columns(value_json: { 'department_code' => '02' }, external_id: '200070308')

    render

    expect(page).to have_select(champ.focusable_input_id, selected: 'Sélectionnez')
  end
end
