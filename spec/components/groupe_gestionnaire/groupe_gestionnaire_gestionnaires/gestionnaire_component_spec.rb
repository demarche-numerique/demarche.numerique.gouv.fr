# frozen_string_literal: true

RSpec.describe GroupeGestionnaire::GroupeGestionnaireGestionnaires::GestionnaireComponent, type: :component do
  let(:gestionnaire) { build_stubbed(:gestionnaire) }
  let(:component) { described_class.new(groupe_gestionnaire: nil, gestionnaire:, is_gestionnaire: false) }

  before { allow(component).to receive(:current_gestionnaire).and_return(gestionnaire) }

  it "flags the current account in English" do
    I18n.with_locale(:en) { render_inline(component) }
    expect(page).to have_css("td", exact_text: "#{gestionnaire.email} (you)")
  end
end
