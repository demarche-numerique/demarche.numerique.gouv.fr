# frozen_string_literal: true

RSpec.describe Procedure::SVASVRFormComponent, type: :component do
  before_all { seed "cases/sva" }

  let(:procedure) { procedures.individual }

  subject(:rendered) { render_inline(described_class.new(procedure: procedure, configuration: procedure.sva_svr_configuration)) }

  let(:sva_enabled) { true }
  before { allow(procedure).to receive(:feature_enabled?).with(:sva).and_return(sva_enabled) }

  context "when sva feature is disabled" do
    let(:sva_enabled) { false }

    it "shows contact information and disables form" do
      expect(rendered).to have_text(/Pour activer le paramétrage.*contactez-nous/)
      expect(rendered).to have_field('Silence Vaut Accord', disabled: true)
    end
  end

  context "when procedure is published with config" do
    let(:procedure) { procedures.sva }

    it "freezes the form and leads to the disabling" do
      expect(rendered).to have_field('Silence Vaut Accord', disabled: true)
      expect(rendered).to have_button('Enregistrer', disabled: true)
      expect(rendered).to have_link('Désactiver le SVA', href: %r{/sva_svr_disabling/new})
    end
  end

  context "when procedure is declarative" do
    let(:procedure) { create(:procedure, :published, declarative_with_state: :en_instruction) }

    it "shows incompatibility warning" do
      expect(rendered).to have_text(/incompatible avec les démarches déclaratives/i)
      expect(rendered).to have_link("Désactiver le déclaratif")
      expect(rendered).to have_field('Silence Vaut Accord', disabled: true)
      expect(rendered).to have_button('Enregistrer', disabled: true)
    end
  end

  context "when procedure is brouillon with sva enabled" do
    let(:procedure) { create(:procedure, :draft, :sva) }

    it "shows enabled form with all options" do
      expect(rendered).to have_field('Silence Vaut Accord', type: 'radio', disabled: false)
      expect(rendered).to have_field('Silence Vaut Rejet', type: 'radio', disabled: false)
      expect(rendered).to have_button('Enregistrer', disabled: false)
    end
  end
end
