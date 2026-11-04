# frozen_string_literal: true

RSpec.describe Dsfr::SidemenuComponent, type: :component do
  subject do
    render_inline(described_class.new) do |component|
      component.with_links([{ name: "Voir les avis", url: "/avis", **link_options }])
    end
  end

  context "without a count" do
    let(:link_options) { {} }

    it "renders the link alone" do
      expect(subject).to have_link("Voir les avis", exact: true)
      expect(subject).not_to have_css(".fr-sidemenu__count")
    end
  end

  context "with a positive count" do
    let(:link_options) { { count: 2, count_label: "2 avis rendus" } }

    it "shows the count and gives screen readers its label" do
      expect(subject).to have_css(".fr-sidemenu__count[aria-hidden='true']", text: "(2)")
      expect(subject).to have_css("a .fr-sr-only", text: ", 2 avis rendus")
    end
  end

  context "with a zero count" do
    let(:link_options) { { count: 0, count_label: "0 avis rendu" } }

    it "shows nothing" do
      expect(subject).not_to have_css(".fr-sidemenu__count")
      expect(subject).not_to have_text("0 avis rendu")
    end
  end
end
