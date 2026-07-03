# frozen_string_literal: true

describe 'views/shared/champs/multiple_drop_down_list/_show', type: :view do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :multiple_drop_down_list }]) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.project_champs_public.first }

  before { champ.update(value: champ.drop_down_options) }
  subject { render partial: 'shared/champs/multiple_drop_down_list/show', locals: { champ: } }

  it 'renders the view' do
    subject
    expect(rendered).to have_selector('li', count: champ.selected_options.size)
  end
end
