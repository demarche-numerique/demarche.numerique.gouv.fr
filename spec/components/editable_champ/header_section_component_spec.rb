# frozen_string_literal: true

RSpec.describe EditableChamp::HeaderSectionComponent, type: :component do
  subject { render_inline(component) }

  let(:champ) { Champs::HeaderSectionChamp.new }

  let(:dossier) { instance_double(Dossier, auto_numbering_section_headers_for?: false) }

  before do
    allow(champ).to receive(:level).and_return(1)
    allow(champ).to receive(:libelle).and_return("Ma section")
    allow(champ).to receive(:visible?).and_return(true)
    allow(champ).to receive(:dossier).and_return(dossier)
    allow(champ).to receive(:type_de_champ).and_return(double)
    allow(champ).to receive(:input_group_id).and_return("section-test")
  end

  context "with visual heading (default)" do
    let(:component) { described_class.new(champ: champ) }

    it "adds DSFR heading class" do
      expect(subject).to have_css("h3.fr-h2", text: "Ma section")
    end
  end

  context "without visual heading" do
    let(:component) { described_class.new(champ: champ, with_visual_heading: false) }

    it "does not add DSFR heading class" do
      expect(subject).to have_css("h3", text: "Ma section")
      expect(subject).not_to have_css(".fr-h2")
    end
  end
end
