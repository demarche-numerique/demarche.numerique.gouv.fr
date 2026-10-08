# frozen_string_literal: true

describe 'layouts/_display_theme_modal', type: :view do
  let(:modal_html) { rendered }

  before { render partial: 'layouts/display_theme_modal' }

  it_behaves_like 'a labelled DSFR modal', 'fr-theme-modal'

  it 'keeps the markup the DSFR display script relies on' do
    expect(rendered).to have_css('#fr-display input[name="fr-radios-theme"]', count: 3, visible: :all)
  end
end
