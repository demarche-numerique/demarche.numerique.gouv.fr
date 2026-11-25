# frozen_string_literal: true

RSpec.describe GroupeGestionnaire::GroupeGestionnaireAdministrateurs::AdministrateurComponent, type: :component do
  let(:administrateur) { administrateurs.default }
  let(:component) { described_class.new(groupe_gestionnaire: nil, administrateur:, is_gestionnaire: false) }

  before { allow(component).to receive(:current_user).and_return(administrateur.user) }

  it "flags the current account in English" do
    I18n.with_locale(:en) { render_inline(component) }
    expect(page).to have_css("td", exact_text: "#{administrateur.email} (you)")
  end
end
