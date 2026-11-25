# frozen_string_literal: true

RSpec.describe Procedure::ProcedureAdministrateurs::AdministrateurComponent, type: :component do
  let(:administrateur) { administrateurs.default }
  let(:component) { described_class.new(procedure: procedures.individual, administrateur:) }

  before { allow(component).to receive(:current_administrateur).and_return(administrateur) }

  it "flags the current account in English" do
    I18n.with_locale(:en) { render_inline(component) }
    expect(page).to have_css("td", exact_text: "#{administrateur.email} (you)")
  end
end
