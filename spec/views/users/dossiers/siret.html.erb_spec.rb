# frozen_string_literal: true

describe 'users/dossiers/siret', type: :view do
  let(:dossier) { create(:dossier) }
  let(:siret_prefilled_by_pro_connect) { false }

  before do
    sign_in dossier.user
    assign(:dossier, dossier)
    assign(:siret_prefilled_by_pro_connect, siret_prefilled_by_pro_connect)
  end

  subject! { render }

  it 'affiche le formulaire de SIRET sans bandeau ProConnect' do
    expect(rendered).to have_field('Numéro SIRET')
    expect(rendered).not_to have_text('transmis par ProConnect')
  end

  context 'quand le SIRET est prérempli par ProConnect' do
    let(:siret_prefilled_by_pro_connect) { true }

    it 'affiche le bandeau ProConnect' do
      expect(rendered).to have_text('transmis par ProConnect')
    end
  end
end
