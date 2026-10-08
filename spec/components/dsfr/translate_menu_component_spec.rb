# frozen_string_literal: true

RSpec.describe Dsfr::TranslateMenuComponent, type: :component do
  let(:options) { {} }

  subject(:rendered) do
    render_inline(described_class.new(id: "help-menu", **options)) do |component|
      component.with_button { "Aide" }
      "<li>Item</li>".html_safe
    end
  end

  it "renders the DSFR translate skeleton, the button controlling the collapsed menu" do
    expect(rendered).to have_css(".fr-translate.fr-nav > .fr-nav__item > button.fr-translate__btn.fr-btn[aria-controls='help-menu'][aria-expanded='false']", text: "Aide")
    expect(rendered).to have_css(".fr-nav__item > #help-menu.fr-collapse.fr-menu > ul.fr-menu__list > li", text: "Item")
    expect(rendered).not_to have_css("button[title]")
  end

  context "with options" do
    let(:options) do
      { title: "Mon compte", list_tag: :div, button_class: "help-btn", item_class: "fr-nav__item--align-right", menu_class: "help-content", list_class: "max-content" }
    end

    it "applies the title, the list tag and the extra classes" do
      expect(rendered).to have_css(".fr-nav__item.fr-nav__item--align-right > button.fr-translate__btn.fr-btn.help-btn[title='Mon compte']")
      expect(rendered).to have_css("#help-menu.fr-collapse.fr-menu.help-content > div.fr-menu__list.max-content > li")
    end
  end
end
